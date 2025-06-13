from flask import Flask, render_template_string
from datetime import datetime

app = Flask(__name__)

@app.route("/")
def hello():
    today = datetime.now().strftime("%Y-%m-%d")
    # HTML with embedded JavaScript for live time
    html_content = f"""
    <!DOCTYPE html>
    <html>
    <head>
        <title>Flask Time App</title>
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

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
