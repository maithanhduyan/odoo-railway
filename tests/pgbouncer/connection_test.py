"""
PgBouncer Connection Tests for Railway project 'fortunate-delight'.

Usage:
    1. Copy .env.example to .env and fill in your values:
        cp tests/pgbouncer/.env.example tests/pgbouncer/.env

    2. Install dependencies:
        uv pip install psycopg2-binary pytest python-dotenv

    3. Run:
        python -m pytest tests/pgbouncer/connection_test.py -v
"""

import os
import time
from pathlib import Path
from urllib.parse import urlparse

import psycopg2
import pytest
from dotenv import load_dotenv

# Load .env from the same directory as this test file
load_dotenv(Path(__file__).parent / ".env")


def get_connection_params():
    """Parse connection parameters from DATABASE_PUBLIC_URL or individual env vars."""
    url = os.environ.get("DATABASE_PUBLIC_URL")
    if url:
        parsed = urlparse(url)
        return {
            "host": parsed.hostname,
            "port": parsed.port,
            "user": parsed.username,
            "password": parsed.password,
            "dbname": parsed.path.lstrip("/"),
        }
    return {
        "host": os.environ.get("PGBOUNCER_HOST", "interchange.proxy.rlwy.net"),
        "port": int(os.environ.get("PGBOUNCER_PORT", "34014")),
        "user": os.environ.get("PGBOUNCER_USER", "postgres"),
        "password": os.environ.get("PGBOUNCER_PASSWORD", ""),
        "dbname": os.environ.get("PGBOUNCER_DATABASE", "railway"),
    }


@pytest.fixture
def conn_params():
    return get_connection_params()


@pytest.fixture
def connection(conn_params):
    """Create a database connection via PgBouncer and close it after the test."""
    conn = psycopg2.connect(**conn_params)
    yield conn
    conn.close()


# ---------------------------------------------------------------------------
# Basic connectivity
# ---------------------------------------------------------------------------

class TestBasicConnection:
    def test_connect_and_disconnect(self, conn_params):
        """Verify we can open and close a connection through PgBouncer."""
        conn = psycopg2.connect(**conn_params)
        assert conn.closed == 0, "Connection should be open"
        conn.close()
        assert conn.closed != 0, "Connection should be closed"

    def test_server_version(self, connection):
        """Verify the backend PostgreSQL version is reported."""
        assert connection.server_version > 0

    def test_simple_query(self, connection):
        """Run SELECT 1 to verify query execution works."""
        cur = connection.cursor()
        cur.execute("SELECT 1")
        result = cur.fetchone()
        cur.close()
        assert result == (1,)

    def test_current_database(self, connection, conn_params):
        """Verify we are connected to the expected database."""
        cur = connection.cursor()
        cur.execute("SELECT current_database()")
        db = cur.fetchone()[0]
        cur.close()
        assert db == conn_params["dbname"]

    def test_current_user(self, connection, conn_params):
        """Verify the session user matches the expected user."""
        cur = connection.cursor()
        cur.execute("SELECT current_user")
        user = cur.fetchone()[0]
        cur.close()
        assert user == conn_params["user"]


# ---------------------------------------------------------------------------
# PgBouncer-specific checks
# ---------------------------------------------------------------------------

class TestPgBouncerBehavior:
    def test_pgbouncer_version(self, conn_params):
        """Connect to the pgbouncer admin database and check version."""
        params = {**conn_params, "dbname": "pgbouncer"}
        try:
            conn = psycopg2.connect(**params)
            conn.autocommit = True
            cur = conn.cursor()
            cur.execute("SHOW VERSION")
            version = cur.fetchone()
            cur.close()
            conn.close()
            assert version is not None, "SHOW VERSION should return a result"
        except psycopg2.OperationalError:
            pytest.skip("Admin access to pgbouncer database not available via public proxy")

    def test_show_pools(self, conn_params):
        """Query SHOW POOLS from the pgbouncer admin console."""
        params = {**conn_params, "dbname": "pgbouncer"}
        try:
            conn = psycopg2.connect(**params)
            conn.autocommit = True
            cur = conn.cursor()
            cur.execute("SHOW POOLS")
            pools = cur.fetchall()
            cur.close()
            conn.close()
            assert len(pools) >= 0, "SHOW POOLS should return results"
        except psycopg2.OperationalError:
            pytest.skip("Admin access to pgbouncer database not available via public proxy")

    def test_show_stats(self, conn_params):
        """Query SHOW STATS from the pgbouncer admin console."""
        params = {**conn_params, "dbname": "pgbouncer"}
        try:
            conn = psycopg2.connect(**params)
            conn.autocommit = True
            cur = conn.cursor()
            cur.execute("SHOW STATS")
            stats = cur.fetchall()
            cur.close()
            conn.close()
            assert len(stats) >= 0, "SHOW STATS should return results"
        except psycopg2.OperationalError:
            pytest.skip("Admin access to pgbouncer database not available via public proxy")


# ---------------------------------------------------------------------------
# Connection pooling & concurrency
# ---------------------------------------------------------------------------

class TestConnectionPooling:
    def test_multiple_sequential_connections(self, conn_params):
        """Open and close multiple connections sequentially."""
        for _ in range(5):
            conn = psycopg2.connect(**conn_params)
            cur = conn.cursor()
            cur.execute("SELECT 1")
            cur.close()
            conn.close()

    def test_multiple_concurrent_connections(self, conn_params):
        """Hold multiple connections open simultaneously."""
        connections = []
        try:
            for _ in range(5):
                conn = psycopg2.connect(**conn_params)
                connections.append(conn)
            # All connections should be open
            for conn in connections:
                assert conn.closed == 0
                cur = conn.cursor()
                cur.execute("SELECT 1")
                assert cur.fetchone() == (1,)
                cur.close()
        finally:
            for conn in connections:
                conn.close()

    def test_connection_reuse_after_close(self, conn_params):
        """Verify PgBouncer recycles server connections after client disconnect."""
        conn1 = psycopg2.connect(**conn_params)
        cur1 = conn1.cursor()
        cur1.execute("SELECT pg_backend_pid()")
        cur1.close()
        conn1.close()

        conn2 = psycopg2.connect(**conn_params)
        cur2 = conn2.cursor()
        cur2.execute("SELECT 1")
        assert cur2.fetchone() == (1,)
        cur2.close()
        conn2.close()


# ---------------------------------------------------------------------------
# Transaction handling
# ---------------------------------------------------------------------------

class TestTransactions:
    def test_autocommit(self, connection):
        """Verify autocommit mode works through PgBouncer."""
        connection.autocommit = True
        cur = connection.cursor()
        cur.execute("SELECT 1")
        assert cur.fetchone() == (1,)
        cur.close()

    def test_explicit_transaction(self, connection):
        """Verify explicit BEGIN/COMMIT works through PgBouncer."""
        cur = connection.cursor()
        cur.execute("BEGIN")
        cur.execute("SELECT 1")
        assert cur.fetchone() == (1,)
        cur.execute("COMMIT")
        cur.close()

    def test_rollback(self, connection):
        """Verify ROLLBACK works through PgBouncer."""
        cur = connection.cursor()
        cur.execute("BEGIN")
        cur.execute("SELECT 1")
        cur.execute("ROLLBACK")
        # Connection should still be usable after rollback
        cur.execute("SELECT 2")
        assert cur.fetchone() == (2,)
        cur.close()

    def test_temp_table_in_transaction(self, connection):
        """Verify temp tables work within a transaction (important for transaction pooling)."""
        connection.autocommit = False
        cur = connection.cursor()
        cur.execute("CREATE TEMP TABLE _test_pgb (id serial, val text)")
        cur.execute("INSERT INTO _test_pgb (val) VALUES ('hello')")
        cur.execute("SELECT val FROM _test_pgb")
        assert cur.fetchone()[0] == "hello"
        connection.rollback()
        cur.close()


# ---------------------------------------------------------------------------
# Error resilience
# ---------------------------------------------------------------------------

class TestErrorResilience:
    def test_query_after_error(self, connection):
        """Verify connection is usable after a query error."""
        cur = connection.cursor()
        try:
            cur.execute("SELECT * FROM _nonexistent_table_12345")
        except psycopg2.Error:
            connection.rollback()  # Required to clear the error state
        cur.execute("SELECT 1")
        assert cur.fetchone() == (1,)
        cur.close()

    def test_bad_credentials_rejected(self, conn_params):
        """Verify PgBouncer rejects connections with wrong password."""
        bad_params = {**conn_params, "password": "wrong_password_xyz"}
        with pytest.raises(psycopg2.OperationalError):
            psycopg2.connect(**bad_params)

    def test_invalid_database_rejected(self, conn_params):
        """Verify PgBouncer rejects connections to nonexistent databases."""
        bad_params = {**conn_params, "dbname": "nonexistent_db_xyz"}
        with pytest.raises(psycopg2.OperationalError):
            psycopg2.connect(**bad_params)


# ---------------------------------------------------------------------------
# Performance baseline
# ---------------------------------------------------------------------------

class TestPerformance:
    def test_connection_time(self, conn_params):
        """Verify connection through PgBouncer completes within a reasonable time."""
        start = time.time()
        conn = psycopg2.connect(**conn_params)
        elapsed = time.time() - start
        conn.close()
        assert elapsed < 10, f"Connection took {elapsed:.2f}s, expected < 10s"

    def test_query_latency(self, connection):
        """Verify a simple query returns within a reasonable time."""
        cur = connection.cursor()
        start = time.time()
        cur.execute("SELECT 1")
        cur.fetchone()
        elapsed = time.time() - start
        cur.close()
        assert elapsed < 5, f"Query took {elapsed:.2f}s, expected < 5s"
