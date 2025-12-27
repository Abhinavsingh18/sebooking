from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from database import (
    tests_col,
    centers_col,
    prices_col,
    bookings_col,
    admins_col,
    center_users_col,
    categories_col
)

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
def get_tests(category_id: int):
    return list(
        tests_col.find(
            {"category_id": category_id},
            {"_id": 0}
        )
    )


# ---------------- GET CENTERS ----------------
@app.get("/get_centers")
def get_centers(test_id: int):
    prices = list(
        prices_col.find(
            {"test_id": test_id, "enabled": True},
            {"_id": 0}
        )
    )

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
    if tests_col.find_one({"test_name": data["test_name"]}):
        raise HTTPException(status_code=400, detail="Test already exists")

    tests_col.insert_one({
        "id": int(time.time()),
        "category_id": data["category_id"],
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
                "price": float(data["price"]),
                "enabled": bool(data.get("enabled", True))
            }
        },
        upsert=True
    )
    return {"status": "price updated"}

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

@app.get("/center/bookings")
def center_bookings(center_id: int):
    query = {
        "$or": [
            {"center_id": center_id},
            {"center_id": str(center_id)}
        ]
    }

    bookings = list(bookings_col.find(
        query,
        {"_id": 0, "mobile": 0}
    ))

    result = []
    for b in bookings:
        test = tests_col.find_one({"id": b.get("test_id")}, {"_id": 0})

        result.append({
            "booking_id": b.get("booking_id"),
            "patient_name": b.get("patient_name"),
            "test_name": test["test_name"] if test else "",
            "price": b.get("price"),
            "status": b.get("status"),
            "created_at": b.get("created_at")
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
@app.get("/admin/centers")
def admin_get_centers():
    return list(centers_col.find({}, {"_id": 0}))

@app.get("/admin/tests")
def admin_get_tests():
    return list(tests_col.find({}, {"_id": 0}))

@app.get("/admin/pricing")
def admin_pricing(center_id: int):
    result = []

    # get all tests
    tests = list(tests_col.find({}, {"_id": 0}))

    for t in tests:
        price_row = prices_col.find_one(
            {
                "center_id": center_id,
                "test_id": t["id"]
            },
            {"_id": 0}
        )

        result.append({
            "test_id": t["id"],
            "test_name": t["test_name"],
            "category_id": t["category_id"],
            "price": price_row["price"] if price_row else "",
            "enabled": price_row["enabled"] if price_row else False
        })

    return result



@app.get("/admin/center_users")
def get_center_users():
    return list(center_users_col.find({}, {"_id": 0}))
@app.post("/admin/create_center_user")
def create_center_user(data: dict):
    if center_users_col.find_one({"username": data["username"]}):
        raise HTTPException(status_code=400, detail="Username already exists")

    center_users_col.insert_one({
        "center_id": int(data["center_id"]),
        "username": data["username"],
        "password": data["password"]
    })

    return {"status": "center user created"}

# ================= ADD CATEGORY =================
@app.post("/admin/add_category")
def add_category(data: dict):
    if categories_col.find_one({"name": data["name"]}):
        raise HTTPException(status_code=400, detail="Category exists")

    categories_col.insert_one({
        "id": int(time.time()),
        "name": data["name"]
    })
    return {"status": "category added"}


# ================= GET CATEGORIES =================
@app.get("/admin/categories")
def get_categories():
    return list(categories_col.find({}, {"_id": 0}))

@app.post("/admin/update_center_user")
def update_center_user(data: dict):
    result = center_users_col.update_one(
        {"center_id": int(data["center_id"])},
        {"$set": {
            "username": data["username"],
            "password": data["password"]
        }}
    )

    if result.matched_count == 0:
        raise HTTPException(status_code=404, detail="Center user not found")

    return {"status": "center user updated"}
