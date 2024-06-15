#!/bin/bash

# Directory for storing chat files
CHAT_DIR="${HOME}/.ollama_chats"

# File for storing the current model
CURRENT_MODEL_FILE="${HOME}/.ollama_current_model"

# Function to sanitize ${TTY} for use in filenames
sanitize_tty() {
    echo "${TTY}" | sed 's|/|_|g'
}

# Get sanitized TTY
SANITIZED_TTY=$(sanitize_tty)

# Terminal-specific chat index
LOCAL_CHAT_INDEX_FILE="/tmp/.ollama_chat_index_${SANITIZED_TTY}"
LOCAL_CHAT_MODEL_FILE="/tmp/.ollama_chat_model_${SANITIZED_TTY}"

# Ensure chat directory exists
mkdir -p "${CHAT_DIR}"

# Ensure state files exist
touch "${CURRENT_MODEL_FILE}" "${LOCAL_CHAT_INDEX_FILE}" "${LOCAL_CHAT_MODEL_FILE}"

# Set the model
set_model() {
    local model="$1"
    echo "${model}" > "${CURRENT_MODEL_FILE}"
    echo "${model}" > "${LOCAL_CHAT_MODEL_FILE}"
    echo "Model set to '${model}'"
}

init_model() {
    local model
    model=$(cat "${LOCAL_CHAT_MODEL_FILE}" 2>/dev/null)
    if [ -z "${model}" ]; then
        cat "${CURRENT_MODEL_FILE}" > "${LOCAL_CHAT_MODEL_FILE}"
    fi
}

# Get the current model
get_model() {
    init_model

    local model
    model=$(cat "${LOCAL_CHAT_MODEL_FILE}" 2>/dev/null)
    if [ -z "${model}" ]; then
        echo "Model is not set."
    else
        echo "${model}"
    fi
}

# Create a new chat
new_chat() {
    local last_index new_index chat_dir
    last_index=$(ls "${CHAT_DIR}" 2>/dev/null | sort -n | tail -n 1)
    last_index=${last_index:-0}
    new_index=$((last_index + 1))
    chat_dir="${CHAT_DIR}/${new_index}"
    mkdir -p "${chat_dir}"
    echo "${new_index}" > "${LOCAL_CHAT_INDEX_FILE}"
    echo "New chat created with index ${new_index} for terminal session ${TTY}"
}

# Load an existing chat
load_chat() {
    local chat_index="$1"
    local chat_dir="${CHAT_DIR}/${chat_index}"
    if [ -d "${chat_dir}" ]; then
        echo "${chat_index}" > "${LOCAL_CHAT_INDEX_FILE}"
        echo "Chat ${chat_index} loaded for terminal session ${TTY}"
    else
        echo "Error: Chat ${chat_index} does not exist."
        return 1
    fi
}

# Get the current chat index
get_index() {
    local chat_index
    chat_index=$(cat "${LOCAL_CHAT_INDEX_FILE}" 2>/dev/null)
    if [ -z "${chat_index}" ]; then
        echo "Error: No current chat index available."
        return 1
    else
        echo "Chat Index: ${chat_index}"
    fi
}

# Show the chat context of the chat with the provided index, or the current chat if no index is provided
chat_context() {
    local chat_index="${1:-$(cat "${LOCAL_CHAT_INDEX_FILE}" 2>/dev/null)}"
    local chat_dir="${CHAT_DIR}/${chat_index}"
    if [ -z "${chat_index}" ]; then
        echo "Error: No chat index provided and no current chat index available."
        return 1
    fi
    if [ -d "${chat_dir}" ]; then
        for file in $(ls "${chat_dir}" | sort -n); do
            if [[ "${file}" == *_user.txt ]]; then
                echo "User:"
            else
                echo "Assistant:"
            fi
            cat "${chat_dir}/${file}"
            echo ""
        done
    else
        echo "Error: Chat ${chat_index} does not exist."
        return 1
    fi
}

list_models() {
    ollama list
}

# Queries the model
query_model() {
    local user_input="$1"

    local model=$(get_model)
    local chat_index=$(cat "${LOCAL_CHAT_INDEX_FILE}" 2>/dev/null)
    local chat_dir="${CHAT_DIR}/${chat_index}"

    if [ -z "${model}" ]; then
        echo "Model is not set. Use --set-model <model_name> to set the model."
        return 1
    fi

    if [ -z "${chat_index}" ]; then
        echo "No chat loaded. Attempting to create a new chat..."
        new_chat
        chat_index=$(cat "${LOCAL_CHAT_INDEX_FILE}" 2>/dev/null)
        chat_dir="${CHAT_DIR}/${chat_index}"
    fi

    # Determine the new message index
    local message_index=$(ls "${chat_dir}" | sort -n | tail -n 1 | cut -d'-' -f 1)
    message_index=${message_index:-0}
    message_index=$((message_index + 1))

    # Save the user input
    local user_file="${chat_dir}/${message_index}-0_user.txt"
    echo -e "${user_input}" > "${user_file}"

    local assistant_file="${chat_dir}/${message_index}-1_assistant.txt"
    touch "${assistant_file}"

    local context=$(chat_context)
    local instructions="<YOU ARE THE ASSISTANT, START YOUR RESPONSE IN THE NEXT LINE>\n"

    local context_with_new_input="${context}${instructions}"
    local tmpfile=$(mktemp)

    # Run the model and capture the response
    ollama run "${model}" "${context_with_new_input}" --nowordwrap | tee "${tmpfile}"
    local response=$(< "${tmpfile}")
    rm "${tmpfile}"


    # Update context file
    echo -e "${response}\n" > "${assistant_file}"
}

# Retries the last query
retry_query() {
    local chat_index=$(cat "${LOCAL_CHAT_INDEX_FILE}" 2>/dev/null)
    local chat_dir="${CHAT_DIR}/${chat_index}"

    if [ -z "${chat_index}" ]; then
        echo "No chat loaded. Attempting to create a new chat..."
        new_chat
        chat_index=$(cat "${LOCAL_CHAT_INDEX_FILE}" 2>/dev/null)
        chat_dir="${CHAT_DIR}/${chat_index}"
    fi

    # Determine the last message index
    local last_message_index=$(ls "${chat_dir}" | sort -n | tail -n 1 | cut -d'-' -f 1)
    last_message_index=${last_message_index:-0}

    # Check if there is a user file for the last message
    local last_user_file="${chat_dir}/${last_message_index}-0_user.txt"
    if [ ! -f "${last_user_file}" ]; then
        echo "No previous user input found to retry."
        return 1
    fi

    # Read the last user input
    local last_user_input=$(cat "${last_user_file}")

    # Call query_model with the last user input
    query_model "${last_user_input}"
}

# Display help text
display_help() {
    echo "Usage: o [options] [input]"
    echo ""
    echo "Options:"
    echo "  --new, -n               Create a new chat"
    echo "  --load, -l <index>      Load an existing chat by index"
    echo "  --set-model, -sm <model> Set the current model"
    echo "  --get-model, -gm        Get the current model"
    echo "  --index, -i             Get the current chat index"
    echo "  --context, -c [<index>] Show chat context for the provided index or current chat if no index is given"
    echo "  --list                  List available models"
    echo "  --help, -h              Display this help text"
    echo ""
    echo "Input:"
    echo "  Any input text will be sent to the model for a response"
}

# Main function to handle options
o() {
    local new_chat_flag=0
    local load_chat_flag=0
    local set_model_flag=0
    local get_model_flag=0
    local get_index_flag=0
    local chat_context_flag=0
    local list_models_flag=0
    local retry_query_flag=0
    local display_help_flag=0
    local chat_index=""
    local model=""
    local chat_context_index=""
    local user_input=""

    if [[ "$#" -eq 0 ]]; then
        display_help
        return
    fi

    while [[ "$#" -gt 0 ]]; do
        case $1 in
            --new|-n)
                new_chat_flag=1
                ;;
            --load|-l)
                load_chat_flag=1
                if [[ -n "$2" && "$2" != --* ]]; then
                    chat_index="$2"
                    shift
                else
                    echo "Error: --load requires a chat index."
                    return
                fi
                ;;
            --set-model|-sm)
                set_model_flag=1
                if [[ -n "$2" && "$2" != --* ]]; then
                    model="$2"
                    shift
                else
                    echo "Error: --set-model requires a model name."
                    return
                fi
                ;;
            --get-model|-gm)
                get_model_flag=1
                ;;
            --index|-i)
                get_index_flag=1
                ;;
            --context|-c)
                chat_context_flag=1
                if [[ -n "$2" && "$2" != --* ]]; then
                    chat_context_index="$2"
                    shift
                else
                    chat_context_index=""
                fi
                ;;
            --list)
                list_models_flag=1
                ;;
            --retry|-r)
                retry_query_flag=1
                ;;
            --help|-h)
                display_help_flag=1
                ;;
            --*)
                echo "Error: Unrecognized option '$1'"
                display_help_flag=1
                ;;
            *)
                if [ -z "$user_input" ]; then
                    user_input="$1"
                else
                    user_input="$user_input $1"
                fi
                ;;
        esac
        shift
    done

    if [[ $display_help_flag -eq 1 ]]; then
        display_help
        return
    fi

    if [[ $new_chat_flag -eq 1 ]]; then
        new_chat
    fi

    if [[ $load_chat_flag -eq 1 ]]; then
        load_chat "${chat_index}"
    fi

    if [[ $set_model_flag -eq 1 ]]; then
        set_model "${model}"
    fi

    if [[ $get_model_flag -eq 1 ]]; then
        get_model
    fi

    if [[ $get_index_flag -eq 1 ]]; then
        get_index
    fi

    if [[ $chat_context_flag -eq 1 ]]; then
        chat_context "$chat_context_index"
    fi

    if [[ $list_models_flag -eq 1 ]]; then
        list_models
    fi

    if [[ $retry_query_flag -eq 1 ]]; then
        retry_query
    fi

    if [ -n "$user_input" ]; then
        query_model "$user_input"
    fi
}
