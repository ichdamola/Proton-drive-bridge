#!/bin/bash

# Automated Wiki Backup to Proton Drive Script
# This script:
# 1. Cleans old local backups
# 2. Creates new wiki backup
# 3. Uploads to Proton Drive
# 4. Logs all activities

# Configuration
BACKUP_DIR="/root/wiki-backups"
BACKUP_SCRIPT="/root/outline/backup_wiki_v2.sh"
PROTON_REMOTE="protondrive:LRL Backup Automation files/wiki-backups"
LOG_FILE="/var/log/wiki-backup-automation.log"
KEEP_LOCAL_DAYS=7  # Keep local backups for 7 days

# Function to log messages
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S'): $1" | tee -a "$LOG_FILE"
}

# Function to check if required files/directories exist
check_prerequisites() {
    if [ ! -f "$BACKUP_SCRIPT" ]; then
        log_message "ERROR: Backup script not found at $BACKUP_SCRIPT"
        exit 1
    fi
    
    if [ ! -d "$BACKUP_DIR" ]; then
        log_message "Creating backup directory: $BACKUP_DIR"
        mkdir -p "$BACKUP_DIR"
    fi
    
    # Check if rclone is configured
    if ! rclone listremotes | grep -q "protondrive:"; then
        log_message "ERROR: Proton Drive remote not configured in rclone"
        exit 1
    fi
}

# Function to clean old local backups
cleanup_old_backups() {
    log_message "Cleaning up local backups older than $KEEP_LOCAL_DAYS days..."
    
    # Count files before cleanup
    OLD_COUNT=$(find "$BACKUP_DIR" -name "*.tar.gz" -mtime +$KEEP_LOCAL_DAYS | wc -l)
    
    if [ "$OLD_COUNT" -gt 0 ]; then
        find "$BACKUP_DIR" -name "*.tar.gz" -mtime +$KEEP_LOCAL_DAYS -delete
        log_message "Deleted $OLD_COUNT old backup files"
    else
        log_message "No old backup files to delete"
    fi
}

# Function to create wiki backup
create_backup() {
    log_message "Starting wiki backup creation..."
    
    # Make backup script executable
    chmod +x "$BACKUP_SCRIPT"
    
    # Run backup script
    if "$BACKUP_SCRIPT"; then
        log_message "Wiki backup created successfully"
        return 0
    else
        log_message "ERROR: Wiki backup creation failed"
        return 1
    fi
}

# Function to upload to Proton Drive
upload_to_proton() {
    log_message "Uploading today's backup to Proton Drive..."
    
    # Get count of files to upload
    FILES_TO_UPLOAD=$(find "$BACKUP_DIR" -name "*.tar.gz" -mtime -1 | wc -l)
    
    if [ "$FILES_TO_UPLOAD" -eq 0 ]; then
        log_message "WARNING: No recent backup files found to upload"
        return 1
    fi
    
    # Upload with progress and error handling
    if rclone copy "$BACKUP_DIR/" "$PROTON_REMOTE" --include "*.tar.gz" --max-age 24h --progress --log-level INFO; then
        log_message "Successfully uploaded $FILES_TO_UPLOAD backup file(s) to Proton Drive"
        
        # List what was uploaded
        UPLOADED_FILES=$(find "$BACKUP_DIR" -name "*.tar.gz" -mtime -1 -exec basename {} \;)
        log_message "Uploaded files: $UPLOADED_FILES"
        return 0
    else
        log_message "ERROR: Failed to upload backup to Proton Drive"
        return 1
    fi
}

# Function to verify upload
verify_upload() {
    log_message "Verifying upload to Proton Drive..."
    
    # List files on remote to verify
    if rclone lsf "$PROTON_REMOTE" --max-age 24h > /tmp/proton_files.txt 2>/dev/null; then
        REMOTE_COUNT=$(cat /tmp/proton_files.txt | wc -l)
        log_message "Found $REMOTE_COUNT recent file(s) on Proton Drive"
        
        if [ "$REMOTE_COUNT" -gt 0 ]; then
            log_message "Recent files on Proton: $(cat /tmp/proton_files.txt | tr '\n' ' ')"
        fi
        rm -f /tmp/proton_files.txt
    else
        log_message "WARNING: Could not verify files on Proton Drive (may be authentication issue)"
    fi
}

# Function to send summary
send_summary() {
    local status=$1
    local end_time=$(date '+%Y-%m-%d %H:%M:%S')
    
    if [ "$status" = "success" ]; then
        log_message "=== BACKUP COMPLETED SUCCESSFULLY ==="
    else
        log_message "=== BACKUP COMPLETED WITH ERRORS ==="
    fi
    
    log_message "Backup finished at: $end_time"
    log_message "Log file: $LOG_FILE"
    echo "----------------------------------------" >> "$LOG_FILE"
}

# Main execution
main() {
    local start_time=$(date '+%Y-%m-%d %H:%M:%S')
    log_message "=== STARTING AUTOMATED WIKI BACKUP ==="
    log_message "Backup started at: $start_time"
    
    # Check prerequisites
    check_prerequisites
    
    # Step 1: Clean old backups
    cleanup_old_backups
    
    # Step 2: Create new backup
    if ! create_backup; then
        send_summary "error"
        exit 1
    fi
    
    # Step 3: Upload to Proton Drive
    if ! upload_to_proton; then
        send_summary "error"
        exit 1
    fi
    
    # Step 4: Verify upload
    verify_upload
    
    # Summary
    send_summary "success"
}

# Run main function
main "$@"
