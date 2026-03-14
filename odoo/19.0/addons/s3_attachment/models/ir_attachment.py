import logging
import os

from odoo import models

_logger = logging.getLogger(__name__)


def _s3_endpoint():
    ep = os.environ.get('S3_ENDPOINT', '')
    if ep and not ep.startswith(('http://', 'https://')):
        ep = 'https://' + ep
    return ep


def _s3_enabled():
    return bool(os.environ.get('S3_ENDPOINT'))


def _s3_bucket():
    return os.environ.get('S3_BUCKET', 'odoo')


def _get_s3_client():
    import boto3
    return boto3.client(
        's3',
        endpoint_url=_s3_endpoint(),
        aws_access_key_id=os.environ['S3_ACCESS_KEY'],
        aws_secret_access_key=os.environ['S3_SECRET_KEY'],
        region_name=os.environ.get('S3_REGION', 'us-east-1'),
    )


class IrAttachment(models.Model):
    _inherit = 'ir.attachment'

    def _s3_fetch_to_local(self, fname):
        """Download file from S3 and cache on local filesystem."""
        try:
            full_path = self._full_path(fname)
            client = _get_s3_client()
            response = client.get_object(Bucket=_s3_bucket(), Key=fname)
            data = response['Body'].read()
            os.makedirs(os.path.dirname(full_path), exist_ok=True)
            with open(full_path, 'wb') as f:
                f.write(data)
            _logger.debug("S3: fetched and cached %s", fname)
            return True
        except Exception:
            _logger.warning("S3: failed to fetch %s", fname, exc_info=True)
            return False

    def _file_read(self, fname):
        if _s3_enabled():
            full_path = self._full_path(fname)
            if not os.path.isfile(full_path):
                self._s3_fetch_to_local(fname)
        return super()._file_read(fname)

    def _file_write(self, bin_value, checksum):
        fname = super()._file_write(bin_value, checksum)
        if _s3_enabled():
            try:
                _get_s3_client().put_object(
                    Bucket=_s3_bucket(), Key=fname, Body=bin_value,
                )
            except Exception:
                _logger.error("S3: failed to upload %s", fname, exc_info=True)
        return fname

    def _file_delete(self, fname):
        if _s3_enabled():
            try:
                _get_s3_client().delete_object(Bucket=_s3_bucket(), Key=fname)
            except Exception:
                _logger.warning("S3: failed to delete %s", fname, exc_info=True)
        return super()._file_delete(fname)

    def _to_http_stream(self):
        if _s3_enabled() and self.store_fname:
            full_path = self._full_path(self.store_fname)
            if not os.path.isfile(full_path):
                self._s3_fetch_to_local(self.store_fname)
        return super()._to_http_stream()
