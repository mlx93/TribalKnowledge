-- DABstep Database Schema Initialization
-- This runs when the PostgreSQL container starts

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Merchant Category Codes (MCC) table
CREATE TABLE IF NOT EXISTS merchant_category_codes (
    mcc_code VARCHAR(10) PRIMARY KEY,
    category_description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Acquirer Countries table (simplified)
CREATE TABLE IF NOT EXISTS acquirer_countries (
    country_code VARCHAR(3) PRIMARY KEY,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Merchants table (simplified)
CREATE TABLE IF NOT EXISTS merchants (
    merchant_id VARCHAR(50) PRIMARY KEY,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Main payments table (matches actual CSV structure)
CREATE TABLE IF NOT EXISTS payments (
    payment_id VARCHAR(100) PRIMARY KEY,
    merchant_id VARCHAR(50),
    card_brand VARCHAR(20),
    transaction_date TIMESTAMP,
    payment_method VARCHAR(50),
    transaction_amount DECIMAL(15,2),
    transaction_currency VARCHAR(3),
    acquirer_country_code VARCHAR(3),
    issuing_country VARCHAR(3),
    device_type VARCHAR(20),
    shopper_interaction VARCHAR(20),
    card_bin VARCHAR(20),
    is_fraudulent BOOLEAN DEFAULT false,
    is_refused BOOLEAN DEFAULT false,
    aci VARCHAR(10),
    ip_country VARCHAR(3),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Fee structures table (for JSON data)
CREATE TABLE IF NOT EXISTS fee_structures (
    fee_id SERIAL PRIMARY KEY,
    fee_data JSONB,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Indexes for better performance
CREATE INDEX IF NOT EXISTS idx_payments_merchant_id ON payments(merchant_id);
CREATE INDEX IF NOT EXISTS idx_payments_transaction_date ON payments(transaction_date);
CREATE INDEX IF NOT EXISTS idx_payments_card_brand ON payments(card_brand);
CREATE INDEX IF NOT EXISTS idx_payments_acquirer_country ON payments(acquirer_country_code);
