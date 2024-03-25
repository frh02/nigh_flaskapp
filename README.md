# Object Detection Web Application

This web application is built using Flask and integrates object detection models to perform real-time detection on uploaded videos or webcam streams. It supports multiple object detection models and provides a user-friendly interface for interaction.

## Features

- **Real-time Object Detection**: Utilizes YOLOv8-based models for object detection in real-time.
- **Multiple Models Supported**: Supports three different object detection models: ROM, STS, and TUG.
- **Video Upload and Webcam Stream**: Allows users to upload videos for detection or use webcam streams directly.
- **User Interface**: Provides a clean and intuitive user interface for interaction.

## Installation

1. Clone the repository:

    ```bash
    git clone https://github.com/frh02/nigh_flaskapp.git
    ```

2. Install the required dependencies:

    ```bash
    pip install -r requirements.txt
    ```

## Usage

1. Run the Flask application:

    ```bash
    python3 app.py
    ```

2. Access the application in your web browser at `http://localhost:5001`.

3. Choose the desired object detection model: ROM, STS, or TUG.

4. Upload a video file or start the webcam stream.

5. The application will perform real-time object detection on the video stream.

## File Structure

- `app.py`: Main Flask application file containing routes and logic.
- `static/`: Directory for static files such as CSS, JavaScript, and uploaded videos.
- `templates/`: HTML templates for rendering pages.

## Dependencies

- Flask
- Flask-WTF
- OpenCV