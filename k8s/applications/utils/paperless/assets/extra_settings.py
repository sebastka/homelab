
##########################
# Extra Django settings
# https://docs.djangoproject.com/en/6.0/ref/settings/
##########################

CSRF_COOKIE_DOMAIN: Final[str] = None  # os.getenv("PAPERLESS_CUSTOM_COOKIE_DOMAIN", None)
CSRF_COOKIE_HTTPONLY: Final[bool] = __get_boolean("PAPERLESS_CUSTOM_COOKIE_HTTPONLY", "yes")
CSRF_COOKIE_PATH: Final[str] = os.getenv("PAPERLESS_CUSTOM_COOKIE_PATH", "/")
CSRF_COOKIE_SAMESITE: Final[str] = os.getenv("PAPERLESS_CUSTOM_COOKIE_SAMESITE", "Strict")
CSRF_COOKIE_SECURE: Final[bool] = __get_boolean("PAPERLESS_CUSTOM_COOKIE_SECURE", "yes")
