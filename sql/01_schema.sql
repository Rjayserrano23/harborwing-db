DROP DATABASE IF EXISTS harborwing;
CREATE DATABASE harborwing CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE harborwing;

-- 1. Calendar
CREATE TABLE calendar_date (
  calendar_date   DATE PRIMARY KEY,
  day_of_month    TINYINT UNSIGNED NOT NULL,
  is_business_day BOOLEAN NOT NULL,
  CONSTRAINT chk_day_of_month CHECK (day_of_month BETWEEN 1 AND 31)
) ENGINE=InnoDB;

-- 2. Airport
CREATE TABLE airport (
  airport_code  CHAR(3) PRIMARY KEY,
  name          VARCHAR(120) NOT NULL,
  location      VARCHAR(120) NOT NULL,
  other_details TEXT NULL
) ENGINE=InnoDB;

-- 3. Booking agent
CREATE TABLE booking_agent (
  agent_id           INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  agent_name         VARCHAR(120) NOT NULL,
  additional_details TEXT NULL
) ENGINE=InnoDB;

-- 4. Passenger
CREATE TABLE passenger (
  passenger_id   INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  first_name     VARCHAR(60)  NOT NULL,
  second_name    VARCHAR(60)  NULL,
  last_name      VARCHAR(60)  NOT NULL,
  phone_number   VARCHAR(30)  NOT NULL,
  email_address  VARCHAR(120) NOT NULL,
  address_line_1 VARCHAR(120) NOT NULL,
  address_line_2 VARCHAR(120) NULL,
  city           VARCHAR(80)  NOT NULL,
  state_province VARCHAR(80)  NULL,
  country        VARCHAR(80)  NOT NULL,
  other_details  TEXT NULL,
  CONSTRAINT uq_passenger_email UNIQUE (email_address)
) ENGINE=InnoDB;

-- 5. Flight schedule
CREATE TABLE flight_schedule (
  flight_number           VARCHAR(10) PRIMARY KEY,
  airline_code            VARCHAR(3)  NOT NULL,
  aircraft_type_code      VARCHAR(10) NOT NULL,
  origin_airport          CHAR(3) NOT NULL,
  destination_airport     CHAR(3) NOT NULL,
  scheduled_departure_utc DATETIME NOT NULL,
  scheduled_arrival_utc   DATETIME NOT NULL,
  -- ON DELETE RESTRICT: airports in use cannot be deleted
  CONSTRAINT fk_sched_origin FOREIGN KEY (origin_airport)
    REFERENCES airport (airport_code) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT fk_sched_dest FOREIGN KEY (destination_airport)
    REFERENCES airport (airport_code) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT chk_sched_airports CHECK (origin_airport <> destination_airport),
  CONSTRAINT chk_sched_times CHECK (scheduled_arrival_utc > scheduled_departure_utc)
) ENGINE=InnoDB;

-- 6. Flight leg
CREATE TABLE flight_leg (
  leg_id                INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  flight_number         VARCHAR(10) NOT NULL,
  origin_airport        CHAR(3) NOT NULL,
  destination_airport   CHAR(3) NOT NULL,
  actual_departure_utc  DATETIME NULL,   -- NULL until the flight operates
  actual_arrival_utc    DATETIME NULL,
  -- ON DELETE RESTRICT: a schedule that has legs cannot be deleted
  CONSTRAINT fk_leg_schedule FOREIGN KEY (flight_number)
    REFERENCES flight_schedule (flight_number) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT fk_leg_origin FOREIGN KEY (origin_airport)
    REFERENCES airport (airport_code) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT fk_leg_dest FOREIGN KEY (destination_airport)
    REFERENCES airport (airport_code) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT chk_leg_airports CHECK (origin_airport <> destination_airport),
  CONSTRAINT chk_leg_times CHECK (
    actual_departure_utc IS NULL OR actual_arrival_utc IS NULL
    OR actual_arrival_utc > actual_departure_utc)
) ENGINE=InnoDB;

-- 7. Reservation
CREATE TABLE reservation (
  reservation_id      INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  passenger_id        INT UNSIGNED NOT NULL,
  agent_id            INT UNSIGNED NULL,  -- NULL = direct booking
  status_code         VARCHAR(10) NOT NULL,
  ticket_type_code    VARCHAR(10) NOT NULL,
  travel_class_code   VARCHAR(10) NOT NULL,
  created_at_utc      DATETIME NOT NULL,
  party_size          SMALLINT UNSIGNED NOT NULL,
  -- ON DELETE RESTRICT: do not lose bookings by deleting a passenger
  CONSTRAINT fk_res_passenger FOREIGN KEY (passenger_id)
    REFERENCES passenger (passenger_id) ON DELETE RESTRICT ON UPDATE RESTRICT,
  -- ON DELETE SET NULL: deleting an agent keeps the reservation
  CONSTRAINT fk_res_agent FOREIGN KEY (agent_id)
    REFERENCES booking_agent (agent_id) ON DELETE SET NULL ON UPDATE RESTRICT,
  CONSTRAINT chk_party_size CHECK (party_size > 0)
) ENGINE=InnoDB;

-- 8. Payment
CREATE TABLE payment (
  payment_id      INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  status_code     VARCHAR(10) NOT NULL,
  payment_date    DATETIME NOT NULL,
  payment_amount  DECIMAL(10,2) NOT NULL,
  CONSTRAINT chk_payment_amount CHECK (payment_amount > 0)
) ENGINE=InnoDB;

-- 9. Flight cost (history is kept: one row per flight + aircraft + valid_from)
CREATE TABLE flight_cost (
  flight_number       VARCHAR(10) NOT NULL,
  aircraft_type_code  VARCHAR(10) NOT NULL,
  valid_from          DATE NOT NULL,
  valid_to            DATE NOT NULL,
  cost_amount         DECIMAL(10,2) NOT NULL,
  PRIMARY KEY (flight_number, aircraft_type_code, valid_from),
  -- ON DELETE RESTRICT: keep cost history unless deleted deliberately
  CONSTRAINT fk_cost_schedule FOREIGN KEY (flight_number)
    REFERENCES flight_schedule (flight_number) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT fk_cost_from FOREIGN KEY (valid_from)
    REFERENCES calendar_date (calendar_date) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT fk_cost_to FOREIGN KEY (valid_to)
    REFERENCES calendar_date (calendar_date) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT chk_cost_dates CHECK (valid_to >= valid_from),
  CONSTRAINT chk_cost_amount CHECK (cost_amount >= 0)
) ENGINE=InnoDB;

-- 10. Reservation-payment link (many-to-many, no allocation amount)
CREATE TABLE reservation_payment (
  reservation_id INT UNSIGNED NOT NULL,
  payment_id     INT UNSIGNED NOT NULL,
  PRIMARY KEY (reservation_id, payment_id),   -- blocks duplicate pairs
  -- CASCADE: deleting a reservation removes only its links
  CONSTRAINT fk_rp_reservation FOREIGN KEY (reservation_id)
    REFERENCES reservation (reservation_id) ON DELETE CASCADE ON UPDATE RESTRICT,
  -- RESTRICT: a linked payment cannot be deleted (protects financial records)
  CONSTRAINT fk_rp_payment FOREIGN KEY (payment_id)
    REFERENCES payment (payment_id) ON DELETE RESTRICT ON UPDATE RESTRICT
) ENGINE=InnoDB;

-- 11. Reservation-leg link (many-to-many)
CREATE TABLE reservation_leg (
  reservation_id INT UNSIGNED NOT NULL,
  leg_id         INT UNSIGNED NOT NULL,
  PRIMARY KEY (reservation_id, leg_id),       -- blocks duplicate pairs
  -- CASCADE: deleting a reservation removes only its links
  CONSTRAINT fk_rl_reservation FOREIGN KEY (reservation_id)
    REFERENCES reservation (reservation_id) ON DELETE CASCADE ON UPDATE RESTRICT,
  -- RESTRICT: a leg that is linked to a reservation cannot be deleted
  CONSTRAINT fk_rl_leg FOREIGN KEY (leg_id)
    REFERENCES flight_leg (leg_id) ON DELETE RESTRICT ON UPDATE RESTRICT
) ENGINE=InnoDB;

-- Quick check: should list 11 tables
SHOW TABLES;
