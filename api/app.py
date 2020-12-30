import flask
import os
import subprocess
import atexit
from flask import request
from flask import render_template
from flask import send_file
from flask import jsonify
from flask_mysqldb import MySQL
from apscheduler.schedulers.background import BackgroundScheduler

app = flask.Flask(__name__)

app.config['MYSQL_HOST'] = os.environ['MYSQL_HOSTNAME']
app.config['MYSQL_USER'] = os.environ['MYSQL_USER']
app.config['MYSQL_PASSWORD'] = os.environ['MYSQL_PASSWORD']
app.config['MYSQL_DB'] = os.environ['MYSQL_DATABASE']
mysql = MySQL()
mysql.init_app(app)

# Define cron-task
def create_report():
    command = "./report.sh Daily"
    subprocess.call(command, shell=True)

scheduler = BackgroundScheduler()
scheduler.add_job(func=create_report, trigger="interval", days=1)
scheduler.start()

# Shut down the scheduler when exiting the app
atexit.register(lambda: scheduler.shutdown())

# If navigated to directly, list the reports directory and allow downloads
@app.route('/', defaults={'req_path': ''})
@app.route('/<path:req_path>')
def dir_listing(req_path):
    BASE_DIR = 'reports'

    # Joining the base and the requested path
    abs_path = os.path.join(BASE_DIR, req_path)

    # Return 404 if path doesn't exist
    if not os.path.exists(abs_path):
        return abort(404)

    # Check if path is a file and serve
    if os.path.isfile(abs_path):
        return send_file(abs_path)

    # Show directory contents
    files = os.listdir(abs_path)
    return render_template('files.html', files=files)

# Query latest security alerts
@app.route('/api/v1/alerts/latest', methods=['GET'])
def api_latest():
    cursor = mysql.connection.cursor()
    cursor.execute("call LatestSecurityAlerts()")
    data = cursor.fetchall()
    cursor.close()
    return jsonify(data)

# Query alerts generated in the last interval (day, week, month, or year)
@app.route('/api/v1/alerts', methods=['GET'])
def api_id():
    # Check if timeframe was provided as part of the URL.
    # If timeframe is provided, assign it to a variable.
    # If no timeframe is provided, display an error in the browser.
    if 'day' in request.args:
        day = int(request.args['day'])
    elif 'week' in request.args:
        week = int(request.args['week'])
    elif 'month' in request.args:
        month = int(request.args['month'])
    else:
        return "Error: No day, week or month was provided."

app.run(debug=True,use_reloader=False,host='0.0.0.0')
