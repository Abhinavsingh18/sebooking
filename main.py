from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from database import tests_col, centers_col, prices_col, bookings_col
import time

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ---------------- HOME ----------------
@app.get("/")
def home():
    return {"status": "SE Booking API running"}

# ---------------- GET TESTS ----------------
@app.get("/get_tests")
def get_tests(category: str):
    tests = list(tests_col.find({"category": category}, {"_id": 0}))
    return tests

# ---------------- GET CENTERS ----------------
@app.get("/get_centers")
def get_centers(test_id: int):
    prices = list(prices_col.find({"test_id": test_id}, {"_id": 0}))

    result = []
    for p in prices:
        center = centers_col.find_one(
            {"id": p["center_id"]},
            {"_id": 0, "id": 1, "center_name": 1, "address": 1}
        )
        if center:
            result.append({
                "center_id": center["id"],
                "center_name": center["center_name"],
                "address": center["address"],
                "price": p["price"]
            })

    return result

# ---------------- ADD BOOKING ----------------
@app.post("/add_booking")
def add_booking(data: dict):
    booking_id = f"BKG{int(time.time())}"

    booking = {
        "booking_id": booking_id,
        "patient_name": data["name"],
        "mobile": data["mobile"],
        "center_id": data["center_id"],
        "test_id": data["test_id"],
        "price": data["price"],
        "status": "Pending",
        "created_at": int(time.time())
    }

    bookings_col.insert_one(booking)

    return {"booking_id": booking_id}

# ---------------- BOOKING HISTORY (NEW) ----------------
@app.get("/bookings_by_mobile")
def bookings_by_mobile(mobile: str):
    mobile = mobile.strip()

    # Search both string and number (handles old + new data)
    query = {
        "$or": [
            {"mobile": mobile},
            {"mobile": int(mobile)} if mobile.isdigit() else {}
        ]
    }

    bookings = list(bookings_col.find(
        query,
        {"_id": 0, "mobile": 0}
    ))

    result = []
    for b in bookings:
        test = tests_col.find_one({"id": b["test_id"]}, {"_id": 0})
        center = centers_col.find_one({"id": b["center_id"]}, {"_id": 0})

        result.append({
            "booking_id": b["booking_id"],
            "patient_name": b["patient_name"],
            "test_name": test["test_name"] if test else "",
            "center_name": center["center_name"] if center else "",
            "price": b["price"],
            "status": b["status"],
            "date": b["created_at"]
        })

    return result
# ================= ADMIN LOGIN =================
@app.post("/admin/login")
def admin_login(data: dict):
    admin = admins_col.find_one({
        "username": data.get("username"),
        "password": data.get("password")
    })

    if not admin:
        raise HTTPException(status_code=401, detail="Invalid credentials")

    return {"status": "success"}
# ================= ADD TEST =================
@app.post("/admin/add_test")
def add_test(data: dict):
    if tests_col.find_one({"id": data["id"]}):
        raise HTTPException(status_code=400, detail="Test ID already exists")

    tests_col.insert_one({
        "id": int(data["id"]),
        "category": data["category"],
        "test_name": data["test_name"]
    })

    return {"status": "test added"}
# ================= ADD CENTER =================
@app.post("/admin/add_center")
def add_center(data: dict):
    if centers_col.find_one({"id": data["id"]}):
        raise HTTPException(status_code=400, detail="Center ID already exists")

    centers_col.insert_one({
        "id": int(data["id"]),
        "center_name": data["center_name"],
        "address": data["address"]
    })

    return {"status": "center added"}
# ================= SET PRICE (ASSIGN TEST TO CENTER) =================
@app.post("/admin/set_price")
def set_price(data: dict):
    prices_col.update_one(
        {
            "center_id": int(data["center_id"]),
            "test_id": int(data["test_id"])
        },
        {
            "$set": {
                "price": float(data["price"])
            }
        },
        upsert=True
    )

    return {"status": "price set"}
# ================= CENTER LOGIN =================
@app.post("/center/login")
def center_login(data: dict):
    user = center_users_col.find_one({
        "username": data.get("username"),
        "password": data.get("password")
    })

    if not user:
        raise HTTPException(status_code=401, detail="Invalid credentials")

    center = centers_col.find_one({"id": user["center_id"]}, {"_id": 0})

    return {
        "center_id": user["center_id"],
        "center_name": center["center_name"] if center else ""
    }
# ================= CENTER BOOKINGS =================
@app.get("/center/bookings")
def center_bookings(center_id: int):
    bookings = list(bookings_col.find(
        {"center_id": center_id},
        {"_id": 0, "mobile": 0}   # ❌ hide mobile
    ))

    result = []
    for b in bookings:
        test = tests_col.find_one({"id": b["test_id"]}, {"_id": 0})

        result.append({
            "booking_id": b["booking_id"],
            "patient_name": b["patient_name"],
            "test_name": test["test_name"] if test else "",
            "price": b["price"],
            "status": b["status"],
            "created_at": b["created_at"]
        })

    return result
# ================= MARK BOOKING DONE =================
@app.post("/center/mark_done")
def mark_done(data: dict):
    result = bookings_col.update_one(
        {"booking_id": data.get("booking_id")},
        {"$set": {"status": "Done"}}
    )

    if result.matched_count == 0:
        raise HTTPException(status_code=404, detail="Booking not found")

    return {"status": "updated"}
