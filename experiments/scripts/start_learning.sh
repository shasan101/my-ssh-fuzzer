#!/bin/bash

# Define paths
SSH_KEY_DIR="../orchestration/ssh-keys"
SSH_KEY_NAME="learner-ssh"
DOCKER_COMPOSE_DIR="../orchestration"

# Ensure the ssh-keys directory exists
mkdir -p "${SSH_KEY_DIR}"

# Generate SSH key pair if it doesn't exist
if [[ ! -f "${SSH_KEY_DIR}/${SSH_KEY_NAME}" ]]; then
    echo "Generating SSH key pair (${SSH_KEY_NAME})..."
    ssh-keygen -t rsa -b 2048 -N "" -f "${SSH_KEY_DIR}/${SSH_KEY_NAME}"
    chmod 600 "${SSH_KEY_DIR}/${SSH_KEY_NAME}"
    chmod 644 "${SSH_KEY_DIR}/${SSH_KEY_NAME}.pub"
fi

declare -a KNOWN_RA_ALGOS=("RALAMBDA" "RASTAR")

is_known_ra_algo() {
    local arg="$1"
    for algo in "${KNOWN_RA_ALGOS[@]}"; do
        if [[ "${arg}" == "${algo}" ]]; then
            return 0 # True, it's a known RA algo
        fi
    done
    return 1 # False
}

print_usage() {
    echo "Usage:"
    echo "  ./start_learning.sh <SUT>"
    echo "  ./start_learning.sh <SUT> <learning_algorithm>"
    echo
    echo "  <SUT>          : Required. The SSH server to experiment with."
    echo "                        Must be one of: 'openssh6', 'openssh7', 'openssh8', 'dropbear'."
    echo "  <learning_algorithm> : Optional. Specifies the Register Automata (RA) learning algorithm."
    echo "                        If provided, RA learning mode is activated."
    echo "                        Known algorithms: ${KNOWN_RA_ALGOS[*]}. Ignored if not applicable."
    echo
    echo "Examples:"
    echo "Mealy Learning:"
    echo "./start_learning.sh openssh8"
    echo "./start_learning.sh dropbear"
    echo
    echo "RA Learning:"
    echo "./start_learning.sh dropbear RALAMBDA"
    echo "./start_learning.sh openssh8 RASTAR"
    exit 1
}

SUT=""
MODE="mealy" # Default mode
ALGO=""

case $# in
    1)
        SUT="$1"
        # MODE remains "mealy", ALGO remains ""
        ;;
    2)
        SUT="$1"
        if is_known_ra_algo "$2"; then
            MODE="ra"
            ALGO="$2"
        else
            echo "Error: Invalid second argument '$2'." >&2
            echo "For Mealy learning, only one argument (SUT name) is expected." >&2
            echo "For RA learning, the second argument must be a known learning algorithm (${KNOWN_RA_ALGOS[*]})." >&2
            print_usage
        fi
        ;;
    *)
        echo "Error: Incorrect number of arguments." >&2
        print_usage
        ;;
esac


# Validate input and start corresponding docker-compose
if [[ ! "${SUT}" =~ ^(openssh6|openssh7|openssh8|dropbear)$ ]]; then
    echo "Error: Invalid SUT name '${SUT}'."
    print_usage
fi

# Determine which compose file to use
if [[ "${MODE}" == "ra" ]]; then
    if [[ -z "${ALGO}" ]]; then
        echo "Error: RA mode requires a learning algorithm name."
        print_usage
    fi
    COMPOSE_FILE="docker-compose-${SUT}-ra.yaml"
else
    COMPOSE_FILE="docker-compose-${SUT}.yaml"
fi

# Run the appropriate docker compose setup
if [[ -f "${DOCKER_COMPOSE_DIR}/${COMPOSE_FILE}" ]]; then
    pushd "${DOCKER_COMPOSE_DIR}" > /dev/null
    echo "Starting ${MODE:-mealy} learning experiment for ${SUT}..."

    if [[ "${MODE}" == "ra" ]]; then
        export SEED=1
        export RUN_ID="ra_${SEED}_$(date "+%d-%m-%y-%H-%M")"
        LEARNING_ALGORITHM=${ALGO} OUTPUT_DIR="${RUN_ID}" docker compose -f "${COMPOSE_FILE}" -p $RUN_ID -p ${SEED} up --build
    else
        docker compose -f "${COMPOSE_FILE}" up --build
    fi

    popd > /dev/null
else
    echo "Error: ${COMPOSE_FILE} not found in ${DOCKER_COMPOSE_DIR}"
    exit 1
fi
