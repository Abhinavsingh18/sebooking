from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from database import (
    tests_col,
    centers_col,
    prices_col,
    bookings_col,
    admins_col,
    center_users_col,
    admins_col,
    center_users_col,
    categories_col,
    notices_col,
    agents_col
)

import time
import razorpay

RAZORPAY_KEY_ID = "rzp_test_TUhQRyYIroBgEx"
RAZORPAY_KEY_SECRET = "70DK3sqiKP1qjR28KLcevEyi"
razorpay_client = razorpay.Client(auth=(RAZORPAY_KEY_ID, RAZORPAY_KEY_SECRET))

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

# ---------------- GET NOTICE ----------------
@app.get("/get_notice")
def get_notice():
    notice = notices_col.find_one({"id": "home_notice"}, {"_id": 0})
    if not notice:
        return {"text": "", "enabled": False}
    return notice

# ---------------- UPDATE NOTICE ----------------
@app.post("/admin/update_notice")
def update_notice(data: dict):
    notices_col.update_one(
        {"id": "home_notice"},
        {
            "$set": {
                "text": data.get("text", ""),
                "enabled": bool(data.get("enabled", False))
            }
        },
        upsert=True
    )
    return {"status": "updated"}

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
            {"id": p["center_id"], "enabled": True},
            {"_id": 0}
        )

        if center:
            result.append({
                "center_id": center["id"],
                "center_name": center["center_name"],
                "address": center["address"],
                "lat": center.get("lat"),
                "lng": center.get("lng"),
                "timings": center.get("timings", []),
                "price": p["price"],
                "enabled": True  # ✅ SEND THIS
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
        "age": data.get("age"),
        "gender": data.get("gender"),
        "address": data.get("address"),
        "center_id": data["center_id"],
        "test_id": data["test_id"],
        "price": data["price"],
        "status": "Pending",
        "created_at": int(time.time()),
        "booked_by": data.get("booked_by", "Customer"),
        "payment_status": data.get("payment_status", "Unpaid")
    }

    print(f"DEBUG: Adding booking with details: {booking}")
    bookings_col.insert_one(booking)
    
    # Remove _id for response
    response_data = booking.copy()
    if "_id" in response_data:
        del response_data["_id"]

    return {"booking_id": booking_id, "saved_data": response_data}

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
        {"_id": 0}  # Return all fields including mobile, age, etc
    ))

    result = []
    for b in bookings:
        test = tests_col.find_one({"id": b["test_id"]}, {"_id": 0})
        center = centers_col.find_one({"id": b["center_id"]}, {"_id": 0})

        result.append({
            "booking_id": b["booking_id"],
            "patient_name": b["patient_name"],
            "mobile": b.get("mobile"),
            "age": b.get("age"),
            "gender": b.get("gender"),
            "address": b.get("address"),
            "test_name": test["test_name"] if test else "",
            "center_name": center["center_name"] if center else "",
            "price": b["price"],
            "status": b["status"],
            "date": b["created_at"],
            "payment_status": b.get("payment_status", "Unpaid"),
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
        raise HTTPException(status_code=400, detail="Center exists")

    centers_col.insert_one({
        "id": data["id"],
        "center_name": data["center_name"],
        "address": data["address"],
        "lat": data.get("lat"),
        "lng": data.get("lng"),
        "timings": data.get("timings", []),
        "enabled": True
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
            "created_at": b.get("created_at"),
            "booked_by": b.get("booked_by", "Customer"),
            "payment_status": b.get("payment_status", "Unpaid")
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

    tests = list(tests_col.find({}, {"_id": 0}))

    for t in tests:
        price_row = prices_col.find_one(
            {
                "$or": [
                    {"center_id": center_id, "test_id": t.get("id")},
                    {"center_id": str(center_id), "test_id": t.get("id")}
                ]
            },
            {"_id": 0}
        )

        result.append({
            "test_id": t.get("id"),
            "test_name": t.get("test_name", ""),
            "category_id": t.get("category_id"),
            "price": price_row.get("price") if price_row else "",
            "enabled": price_row.get("enabled", False) if price_row else False
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

# UPDATE CENTER DETAILS
@app.post("/admin/update_center")
def update_center(data: dict):
    update_data = {
        "center_name": data["center_name"],
        "address": data["address"],
    }

    if "lat" in data and data["lat"] is not None:
        update_data["lat"] = float(data["lat"])

    if "lng" in data and data["lng"] is not None:
        update_data["lng"] = float(data["lng"])

    if "timings" in data:
        update_data["timings"] = data["timings"]

    result = centers_col.update_one(
        {"id": int(data["id"])},
        {"$set": update_data}
    )

    if result.matched_count == 0:
        raise HTTPException(status_code=404, detail="Center not found")

    return {"status": "center updated"}


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

@app.post("/admin/update_test")
def update_test(data: dict):
    result = tests_col.update_one(
        {"id": int(data["test_id"])},
        {"$set": {"test_name": data["test_name"]}}
    )
    return {"status": "updated"}

@app.post("/admin/toggle_center")
def toggle_center(data: dict):
    result = centers_col.update_one(
        {"id": int(data["center_id"])},
        {"$set": {"enabled": bool(data["enabled"])}}
    )

    if result.matched_count == 0:
        raise HTTPException(status_code=404, detail="Center not found")

    return {"status": "updated"}


@app.get("/admin/bookings")
def admin_all_bookings():
    bookings = list(bookings_col.find({}, {"_id": 0}))

    result = []
    for b in bookings:
        test = tests_col.find_one({"id": b["test_id"]}, {"_id": 0})
        center = centers_col.find_one({"id": b["center_id"]}, {"_id": 0})

        result.append({
            "booking_id": b["booking_id"],
            "patient_name": b["patient_name"],
            "mobile": b["mobile"],
            "age": b.get("age"),
            "gender": b.get("gender"),
            "address": b.get("address"),
            "test_name": test["test_name"] if test else "",
            "center_name": center["center_name"] if center else "",
            "price": b.get("price", 0),
            "status": b["status"],
            "created_at": b["created_at"],
            "booked_by": b.get("booked_by", "Customer"),
            "payment_status": b.get("payment_status", "Unpaid"),
            "agent_collected": b.get("agent_collected", 0),
            "center_collected": b.get("center_collected", 0),
            "admin_collected": b.get("admin_collected", 0)
        })

    return result


# ================= AGENT SECTION =================

@app.post("/agent/login")
def agent_login(data: dict):
    agent = agents_col.find_one({
        "username": data.get("username"),
        "password": data.get("password")
    })

    if not agent:
        raise HTTPException(status_code=401, detail="Invalid credentials")

    return {
        "agent_id": str(agent["_id"]),
        "agent_name": agent["name"]
    }

@app.get("/admin/agents")
def get_agents():
    # Convert ObjectId to str for JSON serialization if needed, 
    # but here we just return list. _id needs care.
    agents = list(agents_col.find({}, {"_id": 0, "password": 0})) 
    # If we want to return IDs we might need to cast _id. 
    # For now let's rely on 'username' as unique or add a custom id.
    return agents

@app.post("/admin/add_agent")
def add_agent(data: dict):
    if agents_col.find_one({"username": data["username"]}):
        raise HTTPException(status_code=400, detail="Agent exists")

    agents_col.insert_one({
        "name": data["name"],
        "username": data["username"],
        "password": data["password"],
        "created_at": int(time.time())
    })
    return {"status": "agent added"}

@app.post("/center/update_payment_status")
def update_payment(data: dict):
    result = bookings_col.update_one(
        {"booking_id": data.get("booking_id")},
        {"$set": {"payment_status": data.get("payment_status")}}
    )
    if result.matched_count == 0:
        raise HTTPException(status_code=404, detail="Booking not found")
    return {"status": "updated"}

# ================= UPDATE PAYMENT COLLECTION DETAILS (ADMIN & OTHERS) =================
@app.post("/create_payment_order")
def create_payment_order(data: dict):
    booking_id = data.get("booking_id")
    booking = bookings_col.find_one({"booking_id": booking_id})
    if not booking:
        raise HTTPException(status_code=404, detail="Booking not found")

    amount = int(float(booking.get("price", 0)) * 100) # Razorpay accepts amount in paise
    if amount <= 0:
        raise HTTPException(status_code=400, detail="Invalid amount for payment")

    try:
        order = razorpay_client.order.create({
            "amount": amount,
            "currency": "INR",
            "receipt": booking_id,
            "notes": {
                "booking_id": booking_id,
                "patient_name": booking.get("patient_name", "")
            }
        })
        
        # Save order ID in db
        bookings_col.update_one(
            {"booking_id": booking_id},
            {"$set": {"razorpay_order_id": order["id"]}}
        )

        return {"order_id": order["id"], "amount": amount, "currency": "INR"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/verify_payment")
def verify_payment(data: dict):
    booking_id = data.get("booking_id")
    razorpay_order_id = data.get("razorpay_order_id")
    razorpay_payment_id = data.get("razorpay_payment_id")
    razorpay_signature = data.get("razorpay_signature")

    try:
        # This will throw an exception if signature is invalid
        razorpay_client.utility.verify_payment_signature({
            'razorpay_order_id': razorpay_order_id,
            'razorpay_payment_id': razorpay_payment_id,
            'razorpay_signature': razorpay_signature
        })

        # Signature is valid, update booking
        bookings_col.update_one(
            {"booking_id": booking_id},
            {"$set": {
                "payment_status": "Paid",
                "razorpay_payment_id": razorpay_payment_id,
                "razorpay_order_id": razorpay_order_id,
                "razorpay_signature": razorpay_signature
            }}
        )
        return {"status": "success", "message": "Payment verified successfully"}
    except razorpay.errors.SignatureVerificationError:
        bookings_col.update_one(
            {"booking_id": booking_id},
            {"$set": {"payment_status": "Failed"}}
        )
        raise HTTPException(status_code=400, detail="Payment verification failed: Invalid signature")
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/update_payment_details")
def update_payment_details(data: dict):
    booking_id = data.get("booking_id")
    agent_coll = float(data.get("agent_collected", 0))
    center_coll = float(data.get("center_collected", 0))
    admin_coll = float(data.get("admin_collected", 0))
    updated_by = data.get("updated_by_name", "System")

    # Get current booking for price check
    booking = bookings_col.find_one({"booking_id": booking_id})
    if not booking:
        raise HTTPException(status_code=404, detail="Booking not found")

    price = float(booking.get("price", 0))
    
    # Calculate Total Paid
    total_paid = agent_coll + center_coll + admin_coll
    
    # Determine Status
    new_status = "Unpaid"
    # If explicitly setting status via logic or relying on amount
    if total_paid >= price:
        new_status = "Paid"
    elif total_paid > 0:
        new_status = f"Partially Paid ({int(total_paid)}/{int(price)})"
    else:
        new_status = "Unpaid"

    result = bookings_col.update_one(
        {"booking_id": booking_id},
        {"$set": {
            "agent_collected": agent_coll,
            "center_collected": center_coll,
            "admin_collected": admin_coll,
            "last_payment_update_by": updated_by,
            "payment_status": new_status
        }}
    )
    
    return {"status": "updated", "payment_status": new_status, "total_paid": total_paid}
