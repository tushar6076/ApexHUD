import time


def check_actual_connection(app, timeout=3.0):
    """True only if the ESP sent a reply/telemetry packet recently."""
    return (
        app.receiver.running
        and time.time() - app.receiver.last_message_time < timeout
    )
