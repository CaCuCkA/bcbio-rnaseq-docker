#!/bin/bash

IMAGE_NAME="kallisto-pipeline"
IMAGE_TAG="latest"

TRANSCRIPTS_VOLUME="transcripts_volume"
RNA_DATA_VOLUME="rna_data_volume"

HOST_OUTPUT_DIR=${HOST_OUTPUT_DIR:-"output"}
CONTAINER_OUTPUT_DIR="/data/output"

CONTAINER_TRANSCRIPTS_DIR="/data/transcripts"
CONTAINER_RNA_DATA_DIR="/data/rna_data"

log_info() {
    echo -e "[INFO] $1"  # Green
}

log_error() {
    echo -e "\033[31m[ERROR] $1\033[0m" >&2  # Red
}

log_warn() {
    echo -e "\033[33m[WARN] $1\033[0m" >&2  # Yellow
}

log_success() {
    echo -e "\033[32m[SUCCESS] $1\033[0m"  # Green
}

check_docker() {
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed or not in PATH. Please install Docker first."
        exit 1
    fi
}

create_volumes() {
    for volume in "$TRANSCRIPTS_VOLUME" "$RNA_DATA_VOLUME"; do
        if ! docker volume inspect "$volume" > /dev/null 2>&1; then
            log_info "Creating Docker volume: $volume"
            if ! docker volume create "$volume"; then
                log_error "Failed to create Docker volume: $volume"
                exit 1
            fi
        else
            log_info "Docker volume '$volume' already exists."
        fi
    done
}

prepare_host_output_dir() {
    if ! mkdir -p "$HOST_OUTPUT_DIR" || [ ! -w "$HOST_OUTPUT_DIR" ]; then
        log_error "Cannot create or write to host output directory: $HOST_OUTPUT_DIR"
        exit 1
    fi
}

cleanup_resources() {
    log_info "Stopping and removing Docker containers for image '$IMAGE_NAME:$IMAGE_TAG'..."
    docker ps -a --filter "ancestor=$IMAGE_NAME:$IMAGE_TAG" -q | while read -r container_id; do
        log_info "Stopping container: $container_id"
        docker stop "$container_id" || log_warn "Failed to stop container: $container_id"
        log_info "Removing container: $container_id"
        docker rm "$container_id" || log_warn "Failed to remove container: $container_id"
    done

    log_info "Removing Docker image '$IMAGE_NAME:$IMAGE_TAG'..."
    if docker image rm "$IMAGE_NAME:$IMAGE_TAG" > /dev/null 2>&1; then
        log_success "Docker image '$IMAGE_NAME:$IMAGE_TAG' removed successfully."
    else
        log_warn "Docker image '$IMAGE_NAME:$IMAGE_TAG' could not be removed. It might not exist."
    fi

    log_info "Removing Docker volumes..."
    for volume in "$TRANSCRIPTS_VOLUME" "$RNA_DATA_VOLUME"; do
        if docker volume inspect "$volume" > /dev/null 2>&1; then
            if docker volume rm "$volume"; then
                log_success "Docker volume '$volume' removed successfully."
            else
                log_warn "Failed to remove Docker volume '$volume'."
            fi
        else
            log_warn "Docker volume '$volume' does not exist."
        fi
    done
}

main() {
    check_docker

    if [ "$1" == "cleanup" ]; then
        cleanup_resources
        exit 0
    fi

    if ! docker image inspect "$IMAGE_NAME:$IMAGE_TAG" > /dev/null 2>&1; then
        log_info "Docker image '$IMAGE_NAME:$IMAGE_TAG' not found. Building the image..."
        if ! docker build -t "$IMAGE_NAME:$IMAGE_TAG" .; then
            log_error "Failed to build Docker image '$IMAGE_NAME:$IMAGE_TAG'."
            exit 1
        fi
    else
        log_info "Docker image '$IMAGE_NAME:$IMAGE_TAG' found. Running the pipeline..."
    fi

    log_info "Creating necessary Docker volumes..."
    create_volumes

    log_info "Preparing host output directory..."
    prepare_host_output_dir

    log_info "Starting Docker container with mixed mounts..."
    if docker run \
        --mount source="$TRANSCRIPTS_VOLUME",target="$CONTAINER_TRANSCRIPTS_DIR" \
        --mount source="$RNA_DATA_VOLUME",target="$CONTAINER_RNA_DATA_DIR" \
        -v "$(realpath "$HOST_OUTPUT_DIR"):$CONTAINER_OUTPUT_DIR" \
        "$IMAGE_NAME:$IMAGE_TAG" /data/main.sh "$@"; then
        log_success "Docker pipeline execution completed successfully."
    else
        log_error "Docker pipeline execution failed."
        exit 1
    fi
}

main "$@"
