from . import models


def _post_init_hook(env):
    """Upload existing filestore attachments to S3."""
    import logging
    import os
    from .models.ir_attachment import _s3_enabled, _get_s3_client, _s3_bucket

    _logger = logging.getLogger(__name__)

    if not _s3_enabled():
        _logger.info("S3 not configured, skipping filestore sync")
        return

    attachments = env['ir.attachment'].search([
        ('store_fname', '!=', False),
        ('type', '=', 'binary'),
    ])

    if not attachments:
        return

    client = _get_s3_client()
    bucket = _s3_bucket()
    synced = 0

    for att in attachments:
        try:
            full_path = env['ir.attachment']._full_path(att.store_fname)
            if os.path.isfile(full_path):
                with open(full_path, 'rb') as f:
                    client.put_object(Bucket=bucket, Key=att.store_fname, Body=f.read())
                synced += 1
        except Exception:
            _logger.warning("Failed to sync %s to S3", att.store_fname, exc_info=True)

    _logger.info("Synced %d/%d attachments to S3", synced, len(attachments))
