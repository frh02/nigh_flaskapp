import cv2
import pandas as pd
import json 
import random
import pandas as pd
from ultralytics import YOLO
from utils import load_model_ext, norm_kpts, plot_one_box, plot_skeleton_kpts
from config import col_names

def video_sts(path_x):
    conf = 0.5
    model_yolo = YOLO("yolov8m-pose.pt")
    saved_model, meta_str = load_model_ext("model.h5")
    class_names = json.loads(meta_str)
    colors = [[random.randint(0, 255) for _ in range(3)] for _ in class_names]

    video_capture = path_x
    print("Opening")
    vid = cv2.VideoCapture(video_capture)

    if not vid.isOpened():
        print("Error: Couldn't open the video.")
        return
    
    state = "sit"  # Initial state
    counter_list = [0]

    while True:
        ret, img = vid.read()
        if not ret:
            print("End of video.")
            break
        results = model_yolo.predict(img)
        for result in results:
            for box, pose in zip(result.boxes, result.keypoints.data):
                lm_list = []
                for pnt in pose:
                    x, y = pnt[:2]
                    lm_list.append([int(x), int(y)])

                if len(lm_list) == 17:
                    pre_lm = norm_kpts(lm_list)
                    if pre_lm is not None:  # Check if pre_lm is not None
                        data = pd.DataFrame([pre_lm], columns=col_names)
                        predict = saved_model.predict(data)[0]

                        if max(predict) > conf:
                            pose_class = class_names[predict.argmax()]

                            plot_one_box(
                                box.xyxy[0],
                                img,
                                colors[predict.argmax()],
                                f"{pose_class} {max(predict)}",
                            )
                            plot_skeleton_kpts(img, pose, radius=5, line_thick=2, confi=0.5)

                            # State machine to track pose changes
                            if state == "sit" and pose_class == "stand":
                                state = "transition"
                            elif state == "stand" and pose_class == "sit":
                                state = "transition"
                            elif state == "transition" and pose_class == "sit":
                                state = "sit"
                                counter_list[0] += 1
                            elif state == "transition" and pose_class == "stand":
                                state = "stand"

        cv2.putText(
            img,
            "Counter:",
            (20, 50),
            cv2.FONT_HERSHEY_SIMPLEX,
            1,
            (255, 0, 0),
            2,
            cv2.LINE_AA,
        )
        cv2.putText(
            img,
            str(counter_list[0]),
            (200, 50),
            cv2.FONT_HERSHEY_SIMPLEX,
            1,
            (0, 255, 0),
            4,
            cv2.LINE_AA,
        )
        cv2.putText(
            img,
            "State:",
            (20, 100),
            cv2.FONT_HERSHEY_SIMPLEX,
            1,
            (255, 0, 0),
            2,
            cv2.LINE_AA,
        )
        cv2.putText(
            img, state, (200, 100), cv2.FONT_HERSHEY_SIMPLEX, 1, (0, 255, 0), 4, cv2.LINE_AA
        )
        yield img    
    cv2.destroyAllWindows()
