# Genesis Workspace & Agent Operating Rules

## 1. Auto Git Commit & Push Workflow
- ทุกครั้งที่ทำงาน, แก้ไขโค้ด, Refactor หรือเพิ่ม Feature เสร็จสิ้น และผ่านการ Verify เรียบร้อยแล้ว (Build ผ่าน / Linter ผ่าน / Tests ผ่าน):
  1. ตรวจสอบสถานะไฟล์ด้วย `git status`
  2. Stage ไฟล์ที่เกี่ยวข้องทั้งหมด (`git add <files>`)
  3. Commit ด้วยรูปแบบ **Conventional Commits** (เช่น `feat:`, `fix:`, `refactor:`, `perf:`, `docs:`, `test:`) พร้อมข้อความอธิบายการเปลี่ยนแปลงที่ชัดเจน
  4. Push การเปลี่ยนแปลงขึ้น Remote Repository ทันที (`git push origin <branch>`)
  5. แจ้ง Commit Hash, Branch และสรุปไฟล์ที่ถูก Commit ให้ผู้ใช้ทราบในคำตอบ
- ห้ามปล่อยให้งานที่ทำเสร็จแล้วค้างอยู่ในสถานะ Uncommitted เด็ดขาด เว้นแต่ผู้ใช้จะระบุเป็นอย่างอื่น
- **Safety Safeguard**: ห้ามทำ Force Push (`--force`, `-f`) หรือลบ Remote Branch โดยไม่ได้รับการยืนยันอย่างชัดเจนจากผู้ใช้

---

## 2. Code Quality & Engineering Standards
- **Clean Architecture & Modularity**: แยกส่วน UI, Services / Logic, และ Data Store อย่างชัดเจน
- **Type Safety**: ใช้ Strict TypeScript โดยหลีกเลี่ยงการใช้ `any` หรือ Type Casting ที่ไม่จำเป็น
- **Testing & Linting**: รัน `npx oxlint` และ `npm run build` ตรวจสอบความถูกต้องทุกครั้งก่อนส่งมอบงาน
- **Performance**: ระวังเรื่อง LCP, Chunk Splitting และการ Re-render ของ Canvas / Components ที่ไม่จำเป็น
