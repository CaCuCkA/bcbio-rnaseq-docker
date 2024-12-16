#!/bin/bash

log_info() {
    echo -e "[INFO] $1"
}

log_error() {
    echo -e "\033[31m[ERROR] $1\033[0m" >&2
}

log_warn() {
    echo -e "\033[33m[WARN] $1\033[0m" >&2
}

check_args() {
    if [ $# -ne 1 ]; then
        log_warn "Usage: $0 <TRANSCRIPT_LINK>"
        exit 1
    fi
}

initialize_vars() {
    local transcript_link=$1
    local trans_dir="transcripts"
    local arch_name=$(basename "$transcript_link")
    
    echo "$transcript_link $trans_dir $arch_name"
}

download_transcript() {
    local transcript_link=$1
    local trans_dir=$2
    local arch_name=$3 

    cd "$trans_dir" || { log_error "Failed to cd into $trans_dir"; return 1; }

    if [ ! -f "arch/$arch_name" ]; then
        log_info "Downloading transcript from $transcript_link..."
        wget -q "$transcript_link" 
        if [ $? -ne 0 ]; then
            log_error "Failed to download the transcript."
            return 1
        fi
    else
        log_info "Transcript file already exists, moving to arch directory..."
        mv "arch/$arch_name" .
    fi

    log_info "Creating kallisto index for $arch_name..."
    kallisto index -i "$arch_name.idx" "$arch_name"
    if [ $? -ne 0 ]; then
        log_error "Failed to create the index."
        mv "$arch_name" arch/
        return 1
    fi

    mv "$arch_name" arch/
    cd ..

    return 0
}

main() {
    check_args "$@" 
    IFS=" " read -r TRANSCRIPT_LINK TRANS_DIR ARCH_NAME <<< $(initialize_vars "$1")

    if [ ! -f "$TRANS_DIR/$ARCH_NAME.idx" ]; then
        log_info "$ARCH_NAME.idx not found. Downloading and creating the index..." 
        download_transcript "$TRANSCRIPT_LINK" "$TRANS_DIR" "$ARCH_NAME"
        if [ $? -ne 0 ]; then
            log_error "Failed to download or create the index. Exiting..."
            return 1
        else
            log_info "Index created and transcript file moved."
        fi
    else
        log_info "$ARCH_NAME.idx already exists. Skipping download and index creation."
    fi
}

main "$@"
