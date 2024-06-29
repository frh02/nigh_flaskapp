from flask import Flask

app = Flask(__name__)

@app.route('/', methods=['GET','POST'])
@app.route('/home', methods=['GET','POST'])
def home():
    print('HELLO WORLD')


if __name__ == "__main__":
    app.run(debug=True, port=5500)