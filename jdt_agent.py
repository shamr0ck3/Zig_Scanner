import os
from smolagents import CodeAgent, InferenceClientModel, tool

# --- JDT-Mobile Branding ---
print("\033[1;34m" + "="*45)
print("\033[1;31m" + "  🔴🔵 LUARKAN KUASAMU - DSVW SPECIALIST v1.9")
print("\033[1;34m" + "="*45 + "\033[0m")

HF_TOKEN = "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"

@tool
def read_local_file(filepath: str) -> str:
    """
    Reads the content of a local file from the home directory.
    Args:
        filepath: The path or filename to be read (e.g., 'DSVW_Scanner.py').
    """
    try:
        # Resolve ~ to full path for Termux compatibility
        full_path = os.path.expanduser(filepath)
        if not os.path.exists(full_path):
            return f"Error: File '{filepath}' not found."
        with open(full_path, 'r') as f:
            return f.read()
    except Exception as e:
        return f"Error reading file: {str(e)}"

model = InferenceClientModel(
    model_id="Qwen/Qwen2.5-72B-Instruct",
    token=HF_TOKEN
)

agent = CodeAgent(
    tools=[read_local_file], 
    model=model,
    add_base_tools=False
)

try:
    print("[*] JDT-Strategist: Analyzing DSVW vs Intelijen...")
    mission = (
        "1. Use read_local_file to examine 'DSVW_Scanner.py' and 'intelijen_v3.sh'. "
        "2. Explain the core difference in how they detect vulnerabilities. "
        "3. Suggest a way to use the Python DSVW logic inside the Bash script."
    )
    agent.run(mission)
except Exception as e:
    print(f"\n[!] Error: {e}")
