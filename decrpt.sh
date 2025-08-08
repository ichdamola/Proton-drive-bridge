# For today's backup
gpg --decrypt --batch --passphrase "wiki-backup-$(date +%Y%m%d)" backup_file.tar.gz.gpg | tar -xzf -

# For a specific date (e.g., August 5, 2025)
gpg --decrypt --batch --passphrase "wiki-backup-20250805" backup_file.tar.gz.gpg | tar -xzf -
