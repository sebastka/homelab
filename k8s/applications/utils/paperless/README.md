# Paperless-ngx

- Documentation: https://docs.paperless-ngx.com/configuration/
- Git: https://github.com/paperless-ngx/paperless-ngx

## Rootless

Rootlessness achieved by running the [scripts](https://github.com/paperless-ngx/paperless-ngx/tree/dev/scripts) in single process containers:
- webserver: `granian --interface asginl --ws paperless.asgi:application"`
- consumer: `python3 manage.py document_consumer`
- taskqueue: `celery -app paperless beat --loglevel INFO"`
- scheduler: `celery --app paperless worker --loglevel INFO"`

## Sanity check:

Run the following to check for inconsistencies:
- `python3 manage.py document_sanity_checker`
- `kubectl -n paperless exec -it <pod-name> -c paperless-celery-worker -- python3 manage.py document_sanity_checker`
