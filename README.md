# 🌱 โครงการสาธิตระบบแผนที่เกษตรกรรม (Agri-Map Demo Project)

โปรเจกต์ต้นแบบสำหรับทดสอบระบบแผนที่ผ่านดาวเทียม (Sentinel-2) ประกอบด้วย Backend (NestJS), ระบบแปลงแผนที่ (Python Data Pipeline), และ Mobile App (Flutter)

---

## 💻 Tech Stacks
- **Backend:** NestJS, Prisma, PostgreSQL
- **Data Pipeline:** Python, Docker, GDAL
- **Mobile App:** Flutter (Dart)

---

## 🛠️ โครงสร้างของโปรเจกต์

- `backend/` - เซิร์ฟเวอร์ API และการจัดการฐานข้อมูล (NestJS + Prisma + PostgreSQL)
- `data-pipeline/` - สคริปต์อัตโนมัติสำหรับแปลงไฟล์ภาพ `.tif` (จากดาวเทียม Sentinel-2) ให้เป็น XYZ Map Tiles (Python + Docker)
- `mobile_app/` - แอปพลิเคชันฝั่งผู้ใช้งาน (Flutter)

---

## 🏁 คำแนะนำในการตั้งค่าและทดสอบระบบหลัง Clone (Getting Started)

### 1️⃣ การรัน Backend (NestJS + Database)

1. ติดตั้งไลบรารี:
   ```bash
   cd backend
   npm install / npm ci
   ```
2. ตั้งค่าไฟล์ Environment:
   คัดลอกไฟล์ตัวอย่างและใส่ค่าที่ต้องการ (เช่น Database URL, API Keys)
   ```bash
   cp .env.example .env
   ```
   _หมายเหตุ: หากใช้ Docker สำหรับฐานข้อมูล สามารถใช้ค่าเริ่มต้นในไฟล์ตัวอย่างได้เลย_
3. รัน Database ด้วย Docker:
   ```bash
   docker-compose up -d
   ```
4. รัน Migration และ Generate Database:
   ```bash
   npx prisma generate
   npx prisma migrate dev
   ```
4. สตาร์ทเซิร์ฟเวอร์ (API ทดสอบแผนที่จะรันที่ `http://localhost:3000`):
   ```bash
   npm run start:dev
   ```

### 2️⃣ การจำลองผลิตแผนที่ภาพถ่ายดาวเทียม (Data Pipeline)

สคริปต์นี้เอาไว้แปลงรูป `.tif` ให้กลายเป็นชิ้นแผนที่ย่อยๆ (Tiles) และนำส่งไปเก็บที่ Backend

> **สิ่งที่ต้องมี:** โปรแกรม `Docker` เพื่อให้สคริปต์เรียกเครื่องมือลอจิกหั่นภาพ (GDAL) ได้

1. ติดตั้งไลบรารี Python:
   ```bash
   cd data-pipeline
   python3 -m venv venv
   source venv/bin/activate
   pip install requests
   ```
2. ทดสอบนำเข้าแผนที่ตัวอย่าง (สมมติว่าคุณมีไฟล์ `your_map.tif` อยู่):
   ```bash
   python generate_tiles.py --tif your_map.tif --farm-id "FARM_XXXX" --date "YYYY-MM-DD" --layer-type "NDVI"
   ```
   _สคริปต์จะหั่นรูปเสร็จ และบันทึกข้อมูลโชว์ใน Backend ทันที (เช็คได้จาก `http://localhost:3000/map-tiles/FARM_XXXX/dates`)_

### 3️⃣ การรัน Mobile App (Flutter)

แอปเอาไว้แสดงผล Map Tiles ที่เราเพิ่งหั่นเสร็จเมื่อกี้ มาวางทาบบนแผนที่จริง

1. รันเครื่องจำลอง:
   ```bash
   cd mobile_app
   flutter pub get
   ```
2. เช็คที่อยู่ IP เซิร์ฟเวอร์ในมือถือให้ชี้มาที่ Backend สคริปต์ (เช่น `192.168.1.XX:3000` แทน `localhost`) แล้วสั่งรันแอป:
   ```bash
   flutter run
   ```

---

## 🚀 สรุปขั้นตอนหากต้องการนำระบบนี้ไปใช้จริง

ถ้าทีมต้องการนำเฉพาะ "ระบบแผนที่ผ่านดาวเทียมและการดึงข้อมูล" ไปพัฒนาต่อในแอปหลัก โปรดศึกษาการย้ายฐานข้อมูลและฟังก์ชันได้ที่หน้า **[INTEGRATION_GUIDE.md](./INTEGRATION_GUIDE.md)**
