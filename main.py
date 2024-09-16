import subprocess
import time
import json
import os
import struct
from datetime import datetime
from threading import Thread

COUNTER_FILE = "/storage/data/values.store"
DEFAULT_SCALE = 1.0  # Default fallback value for scale
DEFAULT_STATE = 4.0  # Default fallback value for state
DEFAULT_COEF = 0.625  # Default fallback value for coefficient

# Function to read a float value from a specific offset in the file
def read_float_from_file(f, offset):
    f.seek(offset)
    return struct.unpack('>f', f.read(4))[0]

# Function to write a float value to a specific offset in the file
def write_float_to_file(f, offset, value):
    f.seek(offset)
    f.write(struct.pack('>f', value))

# Initialize or update the file with default values
def initialize_file():
    with open(COUNTER_FILE, 'r+b') as f:
        has_counter_dwi = os.path.getsize(f.name) >= 4
        has_scale_dwi = os.path.getsize(f.name) >= 8
        has_counter_acl0 = os.path.getsize(f.name) >= 12
        has_state_acl0 = os.path.getsize(f.name) >= 16
        has_coef_acl0 = os.path.getsize(f.name) >= 20

        if not has_counter_dwi:
            write_float_to_file(f, 0, 0.0)  # Initial counter for dwi0
        if not has_scale_dwi:
            write_float_to_file(f, 4, DEFAULT_SCALE)  # Scale for dwi0
        if not has_counter_acl0:
            write_float_to_file(f, 8, 0.0)  # Initial value for acl0
        if not has_state_acl0:
            write_float_to_file(f, 12, DEFAULT_STATE)  # State for acl0
        if not has_coef_acl0:
            write_float_to_file(f, 16, DEFAULT_COEF)  # Coef for acl0

# Create the file if it doesn't exist and initialize it
if not os.path.exists(COUNTER_FILE):
    os.makedirs(os.path.dirname(COUNTER_FILE), exist_ok=True)
    with open(COUNTER_FILE, 'wb') as f:
        initialize_file()
else:
    initialize_file()

# Now, read the initialized or existing values
with open(COUNTER_FILE, 'r+b') as f:
    scale_dwi = read_float_from_file(f, 4)
    state_acl0 = read_float_from_file(f, 12)
    coef_acl0 = read_float_from_file(f, 16)

def monitor_dwi0():
    previous_value_dwi = None
    while True:
        result_dwi = subprocess.run(['ubus', 'call', 'ioman.dwi.dwi0', 'status'], capture_output=True, text=True)
        output_dwi = result_dwi.stdout

        try:
            data_dwi = json.loads(output_dwi)
            current_value_dwi = data_dwi.get('value', '')
        except json.JSONDecodeError:
            current_value_dwi = ''

        if current_value_dwi == "1" and previous_value_dwi != "1":
            with open(COUNTER_FILE, 'r+b') as f:
                counter_dwi = read_float_from_file(f, 0)
                scale_dwi = read_float_from_file(f, 4)
                counter_dwi = round(counter_dwi + scale_dwi, 1)
                current_time = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
                print(f"dwi0 - New data: {counter_dwi} with scale {scale_dwi} at {current_time}")
                write_float_to_file(f, 0, counter_dwi)  # Update counter_dwi
                write_float_to_file(f, 4, scale_dwi)  # Update scale_dwi

        previous_value_dwi = current_value_dwi
        time.sleep(0.1)

def monitor_acl0():
    while True:
        with open(COUNTER_FILE, 'r+b') as f:
            state_acl0 = read_float_from_file(f, 12)
            coef_acl0 = read_float_from_file(f, 16)

        result_acl = subprocess.run(['ubus', 'call', 'ioman.acl.acl0', 'status'], capture_output=True, text=True)
        output_acl = result_acl.stdout

        try:
            data_acl = json.loads(output_acl)
            current_value_acl = float(data_acl.get('value', 0))
        except (json.JSONDecodeError, ValueError):
            current_value_acl = 0.0

        adjusted_value = max((current_value_acl - state_acl0) * coef_acl0, 0)

        with open(COUNTER_FILE, 'r+b') as f:
            write_float_to_file(f, 8, adjusted_value)  # Update adjusted value for acl0

        print(f"acl0 - New pressure value: {adjusted_value} with coef {coef_acl0} and state {state_acl0} at {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        time.sleep(1)

# Run both monitors in parallel threads
thread_dwi0 = Thread(target=monitor_dwi0)
thread_acl0 = Thread(target=monitor_acl0)

thread_dwi0.start()
thread_acl0.start()

thread_dwi0.join()
thread_acl0.join()