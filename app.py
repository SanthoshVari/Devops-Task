import logging
from flask import Flask, render_template_string
from datetime import datetime

# Configure structured logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s [%(levelname)s] %(message)s',
    handlers=[
        logging.StreamHandler()  # Outputs to stdout for CloudWatch
    ]
)
logger = logging.getLogger(__name__)

app = Flask(__name__)

@app.route("/")
def hello():
    try:
        today = datetime.now().strftime("%Y-%m-%d")
        logger.info(f"Handling request for / - Today's date: {today}")
        html_content = f"""
        <!DOCTYPE html>
        <html>
        <head>
            <title>Flask Time Application by Santosh</title>
            <script>
                function updateTime() {{
                    const now = new Date();
                    const time = now.toLocaleTimeString();
                    document.getElementById("time").innerText = time;
                }}
                setInterval(updateTime, 1000);
            </script>
        </head>
        <body onload="updateTime()">
            <h2>Hello, This is a sample Flask Application!</h2>
            <p>Today's Date: <strong>{today}</strong></p>
            <p>Current Time: <strong id="time"></strong></p>
        </body>
        </html>
        """
        return render_template_string(html_content)
    except Exception as e:
        logger.error(f"Error processing request: {str(e)}", exc_info=True)
        return "Internal Server Error", 500

if __name__ == "__main__":
    logger.info("Starting Flask application on port 5000")
    app.run(host="0.0.0.0", port=5000)