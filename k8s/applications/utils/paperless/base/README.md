# Paperless-ngx

- Git: https://github.com/paperless-ngx/paperless-ngx
- Documentation:
  + Advanced Topics: https://docs.paperless-ngx.com/advanced_usage
  + Administration. https://docs.paperless-ngx.com/administration

## Rootless

Rootlessness achieved by running the [scripts](https://github.com/paperless-ngx/paperless-ngx/tree/dev/scripts) in single process containers:
- webserver: `granian --interface asginl --ws paperless.asgi:application`
- consumer: `python3 manage.py document_consumer`
- taskqueue: `celery -app paperless beat --loglevel INFO`
- scheduler: `celery --app paperless worker --loglevel INFO`

## Administration:

All logs:
- `kubectl -n paperless logs --all-containers --max-log-requests 10 --follow pods/<pod-name>`

Sanity check:
- `python3 manage.py document_sanity_checker`
- `kubectl -n paperless exec -it <pod-name> -c paperless-celery-worker -- python3 manage.py document_sanity_checker`

## To do:

- Look into Flower (`PAPERLESS_ENABLE_FLOWER`)
