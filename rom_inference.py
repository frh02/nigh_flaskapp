import cv2
import mediapipe as mp
from utils import calculate_angle_new
import numpy as np

mp_drawing = mp.solutions.drawing_utils
mp_drawing_styles = mp.solutions.drawing_styles
mp_pose = mp.solutions.pose

def video_rom(path_x):
    video_capture = path_x
    print("Opening")
    vid = cv2.VideoCapture(video_capture)
  
    if not vid.isOpened():
        print("Error: Couldn't open the video.")
        return

    detection_confidence = 0.5
    tracking_confidence = 0.5
    drawing_spec = mp_drawing.DrawingSpec(thickness=2, circle_radius=2)

    with mp_pose.Pose(
            min_detection_confidence=detection_confidence,
            min_tracking_confidence=tracking_confidence) as pose:
        while True:
            ret, frame = vid.read()
            if not ret:
                print("End of video.")
                break

            frame = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
            results = pose.process(frame)

            if results.pose_landmarks is not None:
                frame.flags.writeable = True
                frame = cv2.cvtColor(frame, cv2.COLOR_RGB2BGR)

                landmarks = results.pose_landmarks.landmark
                hip = [landmarks[mp_pose.PoseLandmark.LEFT_HIP.value].x,
                       landmarks[mp_pose.PoseLandmark.LEFT_HIP.value].y]
                knee = [landmarks[mp_pose.PoseLandmark.LEFT_KNEE.value].x,
                        landmarks[mp_pose.PoseLandmark.LEFT_KNEE.value].y]
                ankle = [landmarks[mp_pose.PoseLandmark.LEFT_ANKLE.value].x,
                         landmarks[mp_pose.PoseLandmark.LEFT_ANKLE.value].y]
                hip_r = [landmarks[mp_pose.PoseLandmark.RIGHT_HIP.value].x,
                         landmarks[mp_pose.PoseLandmark.RIGHT_HIP.value].y]
                knee_r = [landmarks[mp_pose.PoseLandmark.RIGHT_KNEE.value].x,
                          landmarks[mp_pose.PoseLandmark.RIGHT_KNEE.value].y]
                ankle_r = [landmarks[mp_pose.PoseLandmark.RIGHT_ANKLE.value].x,
                           landmarks[mp_pose.PoseLandmark.RIGHT_ANKLE.value].y]
                angle = calculate_angle_new(hip, knee, ankle)
                angle_r = calculate_angle_new(hip_r, knee_r, ankle_r)
                angle = round(angle, 1)
                angle_r = round(angle_r, 1)
                # For the left angle
                text_position_left = (20, 60)  # Adjust the coordinates for the desired position
                cv2.putText(frame,"Left Knee: " +  str(angle), text_position_left,
                    cv2.FONT_HERSHEY_DUPLEX, 2, (255, 153, 255), 2, cv2.LINE_AA)

                # For the right angle
                text_position_right = (1200, 60)  # Adjust the coordinates for the desired position
                cv2.putText(frame, "Right Knee: " + str(angle_r), text_position_right,
                            cv2.FONT_HERSHEY_DUPLEX, 2, (150, 150, 0), 2, cv2.LINE_AA)
                # cv2.putText(frame, str(angle),
                #             tuple(np.multiply(knee, [640, 480]).astype(int)),
                #             cv2.FONT_HERSHEY_DUPLEX, 1.5, (255, 153, 255), 2, cv2.LINE_AA)

                # cv2.putText(frame, str(angle_r), tuple(np.multiply(knee_r, [640, 480]).astype(int)),
                #             cv2.FONT_HERSHEY_DUPLEX, 1.5, (150, 150, 0), 2, cv2.LINE_AA)

                mp_drawing.draw_landmarks(
                    image=frame,
                    landmark_list=results.pose_landmarks,
                    connections=mp_pose.POSE_CONNECTIONS,
                    landmark_drawing_spec=mp_drawing_styles.get_default_pose_landmarks_style(),
                    connection_drawing_spec=drawing_spec)
            yield frame
    # vid.release()
    cv2.destroyAllWindows()
