-- 1) Registrations Table
CREATE TABLE IF NOT EXISTS registrations (
  id                SERIAL PRIMARY KEY,
  full_name         VARCHAR(60)  NOT NULL,
  email             VARCHAR(100) NOT NULL UNIQUE,
  phone             CHAR(10)     NOT NULL UNIQUE,
  password_hash     VARCHAR(255) NOT NULL,
  college           VARCHAR(100) NOT NULL,
  register_no       VARCHAR(15)  NOT NULL,
  city              VARCHAR(50)  NOT NULL,
  address           VARCHAR(200) NOT NULL,
  degree            VARCHAR(20)  NOT NULL,
  department        VARCHAR(100) NOT NULL,
  degree_status     VARCHAR(20)  NOT NULL CHECK (degree_status IN ('Studying','Completed')),
  year_of_study     VARCHAR(20)  NULL,
  semester          VARCHAR(20)  NULL,
  completion_year   VARCHAR(4)   NULL,
  course            VARCHAR(100) NOT NULL,
  gender            VARCHAR(10)  NOT NULL CHECK (gender IN ('Female','Male','Other')),
  skills            VARCHAR(255) NOT NULL,
  reset_otp         VARCHAR(10)  NULL,
  reset_otp_expires TIMESTAMP    NULL,
  created_at        TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

ALTER TABLE registrations
ADD COLUMN IF NOT EXISTS reset_otp VARCHAR(10),
ADD COLUMN IF NOT EXISTS reset_otp_expires TIMESTAMP;

-- 2) Login History Table
CREATE TABLE IF NOT EXISTS login_history (
  id               SERIAL PRIMARY KEY,
  registration_id  INT NULL,
  username_entered VARCHAR(100) NOT NULL,
  status           VARCHAR(10)  NOT NULL CHECK (status IN ('SUCCESS','FAILED')),
  login_time       TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_login_registration
    FOREIGN KEY (registration_id) REFERENCES registrations(id)
    ON DELETE SET NULL
);

-- 3) Student Profile Table
CREATE TABLE IF NOT EXISTS student_profile (
  registration_id  INT PRIMARY KEY,
  photo            TEXT NULL,
  location         VARCHAR(100) NULL,
  current_activity VARCHAR(100) NULL,
  current_course   VARCHAR(100) NULL,
  updated_at       TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_profile_registration
    FOREIGN KEY (registration_id) REFERENCES registrations(id) ON DELETE CASCADE
);

CREATE OR REPLACE FUNCTION update_student_profile_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = CURRENT_TIMESTAMP;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_student_profile_updated_at ON student_profile;
CREATE TRIGGER trg_student_profile_updated_at
BEFORE UPDATE ON student_profile
FOR EACH ROW
EXECUTE FUNCTION update_student_profile_timestamp();

-- 4) Student Files Table
CREATE TABLE IF NOT EXISTS student_files (
  id               SERIAL PRIMARY KEY,
  registration_id  INT NOT NULL,
  file_name        VARCHAR(150) NOT NULL,
  file_path        VARCHAR(255) NOT NULL,
  file_size        INT NOT NULL,
  uploaded_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_files_registration
    FOREIGN KEY (registration_id) REFERENCES registrations(id) ON DELETE CASCADE
);

-- 5) Company Location Table (30m radius)
CREATE TABLE IF NOT EXISTS company_location (
  id            SERIAL PRIMARY KEY,
  company_name  VARCHAR(100)  NOT NULL,
  latitude      DECIMAL(10,7) NOT NULL,
  longitude     DECIMAL(10,7) NOT NULL,
  radius_m      INT           NOT NULL DEFAULT 30
);

-- Insert default AR INFOTEK location if empty
INSERT INTO company_location (company_name, latitude, longitude, radius_m)
SELECT 'AR INFOTEK', 12.7543272, 77.8287136, 30
WHERE NOT EXISTS (SELECT 1 FROM company_location);

-- Ensure only 1 clean AR INFOTEK row with exact coordinates & 30m radius
UPDATE company_location
SET company_name = 'AR INFOTEK',
    latitude = 12.7543272,
    longitude = 77.8287136,
    radius_m = 30
WHERE id = (SELECT id FROM company_location ORDER BY id LIMIT 1);

-- 6) Attendance Table
CREATE TABLE IF NOT EXISTS attendance (
  id               SERIAL PRIMARY KEY,
  registration_id  INT NOT NULL,
  company_id       INT NOT NULL DEFAULT 1,
  attendance_date  DATE NOT NULL,
  status           VARCHAR(10) NOT NULL CHECK (status IN ('PRESENT', 'ABSENT')),
  check_in_time    TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  latitude         DECIMAL(10, 7) NOT NULL,
  longitude        DECIMAL(10, 7) NOT NULL,
  distance_m       DECIMAL(12, 1) NOT NULL,
  accuracy_m       DECIMAL(6, 1)  NOT NULL,
  CONSTRAINT uniq_user_date UNIQUE (registration_id, attendance_date),
  CONSTRAINT fk_att_reg FOREIGN KEY (registration_id) REFERENCES registrations(id) ON DELETE CASCADE,
  CONSTRAINT fk_att_company FOREIGN KEY (company_id) REFERENCES company_location(id)
);

-- 7) Public Holidays Table
CREATE TABLE IF NOT EXISTS public_holidays (
  id            SERIAL PRIMARY KEY,
  holiday_date  DATE NOT NULL UNIQUE,
  name          VARCHAR(100) NOT NULL
);

INSERT INTO public_holidays (holiday_date, name) VALUES
('2026-01-01', 'New Year''s Day'),
('2026-01-15', 'Pongal'),
('2026-01-16', 'Thiruvalluvar Day'),
('2026-01-17', 'Uzhavar Thirunal'),
('2026-01-26', 'Republic Day'),
('2026-02-01', 'Thai Poosam'),
('2026-03-19', 'Telugu New Year''s Day'),
('2026-03-21', 'Ramzan (Id-ul-Fitr)'),
('2026-03-31', 'Mahavir Jayanti'),
('2026-04-03', 'Good Friday'),
('2026-04-14', 'Tamil New Year''s Day / Dr B.R. Ambedkar''s Birthday'),
('2026-05-01', 'May Day'),
('2026-05-28', 'Bakrid (Id-ul-Zuha)'),
('2026-06-26', 'Muharram'),
('2026-08-15', 'Independence Day'),
('2026-08-26', 'Milad-un-Nabi'),
('2026-09-04', 'Krishna Jayanthi'),
('2026-09-14', 'Vinayakar Chathurthi'),
('2026-10-02', 'Gandhi Jayanthi'),
('2026-10-19', 'Ayudha Pooja'),
('2026-10-20', 'Vijaya Dasami'),
('2026-11-08', 'Deepavali'),
('2026-12-25', 'Christmas Day')
ON CONFLICT (holiday_date) DO NOTHING;

-- Clear today's test attendance record (IST date)


-- Verify company location & attendance report
SELECT * FROM company_location;

SELECT 
    r.id AS registration_id,
    r.full_name,
    r.register_no,
    r.email,
    a.attendance_date,
    TO_CHAR(a.check_in_time AT TIME ZONE 'UTC' AT TIME ZONE 'Asia/Kolkata', 'DD-Mon-YYYY HH12:MI:SS AM') AS exact_date_time,
    a.status,
    a.distance_m
FROM attendance a
JOIN registrations r ON a.registration_id = r.id
ORDER BY a.check_in_time DESC;