# Both buckets were created in the Cloud Console before this root existed, and imported.

# ------------------------------------------------------------------------------------ databases ---
#
# The nightly database dumps (k8s/common/dbdump2s3): one PGP-encrypted object per database and day,
# under daily/<cluster>/<engine>/<database>/, plus a monthly copy on the 1st, under monthly/. The
# job never deletes anything: retention is the lifecycle policy below alone.
#
# Not Velero's bucket: Velero owns that one from its root, and reports a storage location holding
# folders it did not create as unavailable.

resource "minio_s3_bucket" "databases" {
  bucket = "sebastka-homelab-databases"
  acl    = "private"

  # Object lock can only be enabled when a bucket is created: false here would mean replacing it
  object_locking = true

  lifecycle {
    prevent_destroy = true # Holds the only off-site copies of the databases
  }
}

# Required by object lock, and what keeps a compromised backup job (its key can write) from
# silently replacing or deleting earlier dumps: an overwrite or delete only adds a version.
resource "minio_s3_bucket_versioning" "databases" {
  bucket = minio_s3_bucket.databases.bucket

  versioning_configuration {
    status = "Enabled"
  }
}

# Every new object version is locked for 30 days. COMPLIANCE, not GOVERNANCE: a governance lock can
# be lifted by any key allowed to bypass it, and Hetzner's S3 keys cannot be scoped down, so a
# leaked key (the backup jobs hold one) could remove the very dumps the lock is there to protect. A
# compliance lock cannot be lifted or shortened by anyone: whatever is written stays at least 30
# days, and so does its cost. This default applies to new versions only.
resource "minio_s3_bucket_retention" "databases" {
  bucket          = minio_s3_bucket.databases.bucket
  mode            = "COMPLIANCE"
  unit            = "DAYS"
  validity_period = 30
}

# On a versioned bucket, expiring an object only hides it behind a delete marker: the data stays
# (and is billed) as a noncurrent version. noncurrent_expiration then removes it, a week later, or
# once its 30-day lock has run out. Hetzner supports no other noncurrent condition than days.
resource "minio_ilm_policy" "databases" {
  bucket = minio_s3_bucket.databases.bucket

  rule {
    id         = "daily"
    filter     = "daily/"
    expiration = "30d"

    noncurrent_expiration {
      days = "7d"
    }
  }

  rule {
    id         = "monthly"
    filter     = "monthly/"
    expiration = "365d"

    noncurrent_expiration {
      days = "7d"
    }
  }

  depends_on = [minio_s3_bucket_versioning.databases]
}

# --------------------------------------------------------------------------------------- velero ---
#
# Velero's backups (k8s/infrastructure/storage/velero): backups/ and kopia/. Velero manages them
# itself (each Schedule's TTL), so no lifecycle policy, versioning or lock. Managed here only so the
# bucket is on record and cannot be deleted by accident.

resource "minio_s3_bucket" "velero" {
  bucket = "sebastka-homelab"
  acl    = "private"

  lifecycle {
    prevent_destroy = true
  }
}

# ---------------------------------------------------------------------------------------- files ---
#
# file's data (the NFS server, a KubeVirt VM: the nixos repository's hosts/file/backup.nix), backed
# up nightly by Kopia, one snapshot source per share (Documents, Downloads, Music, Pictures, Torrent,
# Videos; not homelab), into one encrypted repository. Locked as the dumps are, and for the same
# reason (a leaked key could otherwise delete them): 30 days, COMPLIANCE.
#
# Kopia locks what it writes itself (its repository is created with --retention-mode COMPLIANCE
# --retention-period 30d) and renews the locks of what is still in use at each full maintenance
# (--extend-object-locks), so current data stays locked for as long as it is kept; the bucket's
# default lock below is a floor under that. Kopia decides what to keep (its snapshot policies), so
# no expiration of current objects here.

resource "minio_s3_bucket" "files" {
  bucket = "sebastka-homelab-files"
  acl    = "private"

  # Object lock can only be enabled when a bucket is created: false here would mean replacing it
  object_locking = true

  lifecycle {
    prevent_destroy = true # Holds the only off-site copy of file's data
  }
}

# Required by object lock, and what keeps a compromised backup job from silently replacing or
# deleting earlier data: an overwrite or delete only adds a version (Kopia's restore can then go
# back in time with --point-in-time, within the noncurrent versions' lifetime).
resource "minio_s3_bucket_versioning" "files" {
  bucket = minio_s3_bucket.files.bucket

  versioning_configuration {
    status = "Enabled"
  }
}

# Every new object version is locked for 30 days, whatever Kopia asks: compliance, as the dumps'.
resource "minio_s3_bucket_retention" "files" {
  bucket          = minio_s3_bucket.files.bucket
  mode            = "COMPLIANCE"
  unit            = "DAYS"
  validity_period = 30
}

# What Kopia deletes (its maintenance drops the data no snapshot needs any more) only becomes a
# noncurrent version behind a delete marker, still billed: removed a week later, or once its lock
# has run out (Kopia's renewals end when it deletes, so at most 30 days after). No expiration of
# current objects: Kopia alone decides what to keep.
resource "minio_ilm_policy" "files" {
  bucket = minio_s3_bucket.files.bucket

  rule {
    id = "noncurrent"

    noncurrent_expiration {
      days = "7d"
    }
  }

  depends_on = [minio_s3_bucket_versioning.files]
}
