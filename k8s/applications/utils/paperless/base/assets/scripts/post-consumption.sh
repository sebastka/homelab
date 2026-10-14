#/bin/sh
set -eu

printf -- 'A document with an id of %s was just consumed. I know the following additional information about it:\n' "${DOCUMENT_ID}"
printf -- '* Generated File Name: %s\n' "${DOCUMENT_FILE_NAME}"
printf -- '* Document type: %s\n' "${DOCUMENT_TYPE}"
printf -- '* Archive Path: %s\n' "${DOCUMENT_ARCHIVE_PATH}"
printf -- '* Source Path: %s\n' "${DOCUMENT_SOURCE_PATH}"
printf -- '* Created: %s\n' "${DOCUMENT_CREATED}"
printf -- '* Added: %s\n' "${DOCUMENT_ADDED}"
printf -- '* Modified: %s\n' "${DOCUMENT_MODIFIED}"
printf -- '* Thumbnail Path: %s\n' "${DOCUMENT_THUMBNAIL_PATH}"
printf -- '* Download URL: %s\n' "${DOCUMENT_DOWNLOAD_URL}"
printf -- '* Thumbnail URL: %s\n' "${DOCUMENT_THUMBNAIL_URL}"
printf -- '* Owner Name: %s\n' "${DOCUMENT_OWNER}"
printf -- '* Correspondent: %s\n' "${DOCUMENT_CORRESPONDENT}"
printf -- '* Tags: %s\n' "${DOCUMENT_TAGS}"

# printf -- 'It was consumed with the passphrase %s\n' "${PASSPHRASE}"
