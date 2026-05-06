from paperless.settings import *  # noqa: F401,F403
from paperless.settings import __get_boolean  # noqa: F401

LOGGING["loggers"]["granian.access"]["handlers"] = ["file_paperless", "console"]

##########################
# Extra Django settings
# https://docs.djangoproject.com/en/6.0/ref/settings/
##########################

CSRF_COOKIE_NAME: Final[str] = os.getenv("DJANGO_CSRF_COOKIE_NAME", "__Host-csrftoken")
CSRF_COOKIE_DOMAIN: Final[str] = os.getenv("DJANGO_CSRF_COOKIE_DOMAIN", None)
CSRF_COOKIE_HTTPONLY: Final[bool] = __get_boolean("DJANGO_CSRF_COOKIE_HTTPONLY", "yes")
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
