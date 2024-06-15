
# Ollama Chat Script

This script helps manage chat sessions and models for the Ollama tool. It allows creating, loading, and interacting with chat sessions, as well as setting and querying different models.

## Usage

The main function of this script is `o`, which accepts various options and arguments to perform different operations.

### Options

- `--new`, `-n`: Create a new chat.
- `--load`, `-l <index>`: Load an existing chat by index.
- `--set-model`, `-sm <model>`: Set the current model.
- `--get-model`, `-gm`: Get the current model.
- `--index`, `-i`: Get the current chat index.
- `--context`, `-c [<index>]`: Show chat context for the provided index or current chat if no index is given.
- `--list`: List available models.
- `--retry`, `-r`: Retry the last query.
- `--help`, `-h`: Display this help text.

### Input

Any input text after the options will be sent to the model for a response.

### Examples

1. **Creating a New Chat:**

    ```bash
    o --new
    ```

2. **Loading an Existing Chat:**

    ```bash
    o --load 1
    ```

3. **Setting the Model:**

    ```bash
    o --set-model my_model
    ```

4. **Getting the Current Model:**

    ```bash
    o --get-model
    ```

5. **Getting the Current Chat Index:**

    ```bash
    o --index
    ```

6. **Showing Chat Context:**

    ```bash
    o --context
    ```

    To show context for a specific chat index:

    ```bash
    o --context 1
    ```

7. **Listing Available Models:**

    ```bash
    o --list
    ```

8. **Retrying the Last Query:**

    ```bash
    o --retry
    ```

### Functions

- **sanitize_tty:** Sanitizes the TTY for use in filenames.
- **set_model:** Sets the current model.
- **init_model:** Initializes the model state.
- **get_model:** Gets the current model.
- **new_chat:** Creates a new chat.
- **load_chat:** Loads an existing chat.
- **get_index:** Gets the current chat index.
- **chat_context:** Shows the chat context for the provided index or the current chat if no index is provided.
- **list_models:** Lists available models using the `ollama` command.
- **query_model:** Sends input text to the current model and processes the response.
- **retry_query:** Retries the last query.
- **display_help:** Displays help text for the script.

### Environment Variables

- `CHAT_DIR`: Directory for storing chat files (default: `~/.ollama_chats`).
- `CURRENT_MODEL_FILE`: File for storing the current model (default: `~/.ollama_current_model`).

### Dependencies

Ensure the `ollama` command-line tool is installed and accessible in your environment.

## License

This script is released under the MIT License.
