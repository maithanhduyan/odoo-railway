{
    'name': 'S3 Attachment Storage',
    'version': '19.0.1.0.0',
    'summary': 'Store attachments on S3-compatible storage (MinIO)',
    'category': 'Technical',
    'license': 'LGPL-3',
    'depends': ['base'],
    'auto_install': False,
    'post_init_hook': '_post_init_hook',
}
