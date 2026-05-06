from paperless.settings import *  # noqa: F401,F403
from paperless.settings import __get_boolean  # noqa: F401

LOGGING["loggers"]["granian.access"]["handlers"] = ["file_paperless", "console"]

##########################
# Extra Django settings
# https://docs.djangoproject.com/en/6.0/ref/settings/
##########################

CSRF_COOKIE_DOMAIN: Final[str] = os.getenv("PAPERLESS_CUSTOM_COOKIE_DOMAIN", None)
CSRF_COOKIE_HTTPONLY: Final[bool] = __get_boolean("PAPERLESS_CUSTOM_COOKIE_HTTPONLY", "yes")
CSRF_COOKIE_PATH: Final[str] = os.getenv("PAPERLESS_CUSTOM_COOKIE_PATH", "/")
CSRF_COOKIE_SAMESITE: Final[str] = os.getenv("PAPERLESS_CUSTOM_COOKIE_SAMESITE", "Strict")
CSRF_COOKIE_SECURE: Final[bool] = __get_boolean("PAPERLESS_CUSTOM_COOKIE_SECURE", "yes")

SESSION_COOKIE_DOMAIN: Final[str] = CSRF_COOKIE_DOMAIN
SESSION_COOKIE_HTTPONLY: Final[bool] = CSRF_COOKIE_HTTPONLY
SESSION_COOKIE_PATH: Final[str] = CSRF_COOKIE_PATH
SESSION_COOKIE_SAMESITE: Final[str] = CSRF_COOKIE_SAMESITE
SESSION_COOKIE_SECURE: Final[bool] = CSRF_COOKIE_SECURE

LANGUAGE_COOKIE_DOMAIN: Final[str] = CSRF_COOKIE_DOMAIN
LANGUAGE_COOKIE_HTTPONLY: Final[bool] = CSRF_COOKIE_HTTPONLY
LANGUAGE_COOKIE_PATH: Final[str] = CSRF_COOKIE_PATH
LANGUAGE_COOKIE_SAMESITE: Final[str] = CSRF_COOKIE_SAMESITE
LANGUAGE_COOKIE_SECURE: Final[bool] = CSRF_COOKIE_SECURE
