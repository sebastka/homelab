import paperless.settings as _base
import datetime as _dt
import logging as _log

# Import all settings from paperless.settings, including private _names excluded by `import *`
globals().update({k: v for k, v in vars(_base).items() if not (k.startswith("__") and k.endswith("__"))})

# Use the nginx combined log format for access logs
LOGGING["formatters"]["nginx_combined"] = {"format": "%(message)s"}
LOGGING["handlers"]["nginx_access"] = {
    "class": "logging.StreamHandler",
    "formatter": "nginx_combined",
    "stream": "ext://sys.stdout",
}
LOGGING["loggers"]["granian.access"] = {
    "handlers": ["nginx_access"],
    "level": "INFO",
    "propagate": False,
}

_access_logger = _log.getLogger("granian.access")

class AccessLogMiddleware:
    async_capable = True
    sync_capable = False

    def __init__(self, get_response):
        self.get_response = get_response

    async def __call__(self, request):
        response = await self.get_response(request)
        xff = request.META.get("HTTP_X_FORWARDED_FOR", "")
        addr = xff.split(",")[0].strip() if xff else request.META.get("REMOTE_ADDR", "-")
        _access_logger.info(
            '%s - - [%s] "%s %s %s" %d %s "%s" "%s"',
            addr,
            _dt.datetime.now().astimezone().strftime("%d/%b/%Y:%H:%M:%S %z"),
            request.method,
            request.get_full_path(),
            request.META.get("SERVER_PROTOCOL", "HTTP/1.1"),
            response.status_code,
            response.get("Content-Length", "-"),
            request.META.get("HTTP_REFERER", "-"),
            request.META.get("HTTP_USER_AGENT", "-"),
        )
        return response


MIDDLEWARE = ["webserver.AccessLogMiddleware"] + list(MIDDLEWARE)

##########################
# Extra Django settings
# https://docs.djangoproject.com/en/6.0/ref/settings/
##########################

CSRF_COOKIE_NAME: Final[str] = os.getenv("DJANGO_CSRF_COOKIE_NAME", "csrftoken")
CSRF_COOKIE_DOMAIN: Final[str] = os.getenv("DJANGO_CSRF_COOKIE_DOMAIN", None)
CSRF_COOKIE_HTTPONLY: Final[bool] = __get_boolean("DJANGO_CSRF_COOKIE_HTTPONLY", "no")
CSRF_COOKIE_PATH: Final[str] = os.getenv("DJANGO_CSRF_COOKIE_PATH", "/")
CSRF_COOKIE_SAMESITE: Final[str] = os.getenv("DJANGO_CSRF_COOKIE_SAMESITE", "Strict")
CSRF_COOKIE_SECURE: Final[bool] = __get_boolean("DJANGO_CSRF_COOKIE_SECURE", "yes")

SESSION_COOKIE_NAME: Final[str] = os.getenv("DJANGO_SESSION_COOKIE_NAME", "__Host-sessionid")
SESSION_COOKIE_DOMAIN: Final[str] = os.getenv("DJANGO_SESSION_COOKIE_DOMAIN", None)
SESSION_COOKIE_HTTPONLY: Final[bool] = __get_boolean("DJANGO_SESSION_COOKIE_HTTPONLY", "yes")
SESSION_COOKIE_PATH: Final[str] = os.getenv("DJANGO_SESSION_COOKIE_PATH", "/")
SESSION_COOKIE_SAMESITE: Final[str] = os.getenv("DJANGO_SESSION_COOKIE_SAMESITE", "Strict")
SESSION_COOKIE_SECURE: Final[bool] =  __get_boolean("DJANGO_SESSION_COOKIE_SECURE", "yes")

LANGUAGE_COOKIE_NAME: Final[str] = os.getenv("DJANGO_LANGUAGE_COOKIE_NAME", "__Host-django_language")
LANGUAGE_COOKIE_DOMAIN: Final[str] = os.getenv("DJANGO_LANGUAGE_COOKIE_DOMAIN", None)
LANGUAGE_COOKIE_HTTPONLY: Final[bool] = __get_boolean("DJANGO_LANGUAGE_COOKIE_HTTPONLY", "yes")
LANGUAGE_COOKIE_PATH: Final[str] = os.getenv("DJANGO_LANGUAGE_COOKIE_PATH", "/")
LANGUAGE_COOKIE_SAMESITE: Final[str] = os.getenv("DJANGO_LANGUAGE_COOKIE_SAMESITE", "Strict")
LANGUAGE_COOKIE_SECURE: Final[bool] = __get_boolean("DJANGO_LANGUAGE_COOKIE_SECURE", "yes")
