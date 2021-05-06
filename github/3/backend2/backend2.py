from flask import request, Flask
import json
backend2 = Flask(__name__)
@backend2.route('/')
def hello_world():
return ' i am node 2 '
if __name__ == '__main__':
backend2.run(debug=True, host='0.0.0.0')