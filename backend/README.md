# Backend (Agri-Map Demo)

เซิร์ฟเวอร์ API และการจัดการฐานข้อมูลสำหรับโครงการสาธิตระบบแผนที่เกษตรกรรม

## 💻 Tech Stacks
- Framework: NestJS
- Database ORM: Prisma
- Database: PostgreSQL

## ⚙️ การตั้งค่าและรันโปรเจกต์ (Setup)

1. **ติดตั้ง Dependencies:**
   ```bash
   npm install
   ```

2. **ตั้งค่า Environment Variables:**
   คัดลอกไฟล์ `.env.example` เป็น `.env` และกำหนดค่าที่เกี่ยวข้อง (เช่น `DATABASE_URL`)
   ```bash
   cp .env.example .env
   ```

3. **รัน Database ด้วย Docker:**
   ```bash
   docker-compose up -d
   ```

4. **รัน Prisma Migration:**
   ```bash
   cd backend/
   npx prisma generate
   npx prisma migrate dev
   ```

5. **สตาร์ทเซิร์ฟเวอร์:**
   ```bash
   # Development
   npm run start:dev
   
   # Production
   npm run start:prod
   ```

## 🛠️ โครงสร้างสำคัญ
- `src/` - โค้ดหลักของแอปพลิเคชัน (Controllers, Services, Modules)
- `prisma/` - โครงสร้างฐานข้อมูล (Schema) และ Migrations
