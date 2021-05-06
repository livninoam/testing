from flask import request, Flask
import json
backend1 = Flask(__name__)
@backend1.route('/')
def hello_world():
return ' i am node 1 '
if __name__ == '__main__':
backend1.run(debug=True, host='0.0.0.0')