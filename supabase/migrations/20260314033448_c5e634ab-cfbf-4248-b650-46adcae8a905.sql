
-- Create profiles table
CREATE TABLE public.profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  full_name TEXT,
  email TEXT,
  role TEXT DEFAULT 'staff' CHECK (role IN ('manager', 'staff')),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can view all profiles" ON public.profiles FOR SELECT TO authenticated USING (true);
CREATE POLICY "Users can update own profile" ON public.profiles FOR UPDATE TO authenticated USING (auth.uid() = id);
CREATE POLICY "Users can insert own profile" ON public.profiles FOR INSERT TO authenticated WITH CHECK (auth.uid() = id);

-- Auto-create profile on signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, full_name, email, role)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'full_name', ''),
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'role', 'staff')
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Warehouses
CREATE TABLE public.warehouses (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  location TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);
ALTER TABLE public.warehouses ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Authenticated users can view warehouses" ON public.warehouses FOR SELECT TO authenticated USING (true);
CREATE POLICY "Authenticated users can insert warehouses" ON public.warehouses FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "Authenticated users can update warehouses" ON public.warehouses FOR UPDATE TO authenticated USING (true);
CREATE POLICY "Authenticated users can delete warehouses" ON public.warehouses FOR DELETE TO authenticated USING (true);

-- Categories
CREATE TABLE public.categories (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  description TEXT
);
ALTER TABLE public.categories ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Authenticated users can view categories" ON public.categories FOR SELECT TO authenticated USING (true);
CREATE POLICY "Authenticated users can insert categories" ON public.categories FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "Authenticated users can update categories" ON public.categories FOR UPDATE TO authenticated USING (true);
CREATE POLICY "Authenticated users can delete categories" ON public.categories FOR DELETE TO authenticated USING (true);

-- Products
CREATE TABLE public.products (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  sku TEXT UNIQUE NOT NULL,
  category_id UUID REFERENCES public.categories(id),
  unit_of_measure TEXT DEFAULT 'pcs',
  reorder_level INTEGER DEFAULT 10,
  description TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Authenticated users can view products" ON public.products FOR SELECT TO authenticated USING (true);
CREATE POLICY "Authenticated users can insert products" ON public.products FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "Authenticated users can update products" ON public.products FOR UPDATE TO authenticated USING (true);
CREATE POLICY "Authenticated users can delete products" ON public.products FOR DELETE TO authenticated USING (true);

-- Stock
CREATE TABLE public.stock (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id UUID NOT NULL REFERENCES public.products(id),
  warehouse_id UUID NOT NULL REFERENCES public.warehouses(id),
  quantity INTEGER DEFAULT 0,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  UNIQUE(product_id, warehouse_id)
);
ALTER TABLE public.stock ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Authenticated users can view stock" ON public.stock FOR SELECT TO authenticated USING (true);
CREATE POLICY "Authenticated users can insert stock" ON public.stock FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "Authenticated users can update stock" ON public.stock FOR UPDATE TO authenticated USING (true);

-- Receipts
CREATE TABLE public.receipts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  reference_no TEXT UNIQUE NOT NULL DEFAULT '',
  supplier_name TEXT,
  warehouse_id UUID REFERENCES public.warehouses(id),
  status TEXT DEFAULT 'Draft' CHECK (status IN ('Draft', 'Waiting', 'Ready', 'Done', 'Canceled')),
  notes TEXT,
  created_by UUID REFERENCES public.profiles(id),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  validated_at TIMESTAMP WITH TIME ZONE
);
ALTER TABLE public.receipts ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Authenticated users can view receipts" ON public.receipts FOR SELECT TO authenticated USING (true);
CREATE POLICY "Authenticated users can insert receipts" ON public.receipts FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "Authenticated users can update receipts" ON public.receipts FOR UPDATE TO authenticated USING (true);

-- Receipt Items
CREATE TABLE public.receipt_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  receipt_id UUID NOT NULL REFERENCES public.receipts(id) ON DELETE CASCADE,
  product_id UUID NOT NULL REFERENCES public.products(id),
  expected_qty INTEGER DEFAULT 0,
  received_qty INTEGER DEFAULT 0
);
ALTER TABLE public.receipt_items ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Authenticated users can view receipt_items" ON public.receipt_items FOR SELECT TO authenticated USING (true);
CREATE POLICY "Authenticated users can insert receipt_items" ON public.receipt_items FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "Authenticated users can update receipt_items" ON public.receipt_items FOR UPDATE TO authenticated USING (true);
CREATE POLICY "Authenticated users can delete receipt_items" ON public.receipt_items FOR DELETE TO authenticated USING (true);

-- Deliveries
CREATE TABLE public.deliveries (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  reference_no TEXT UNIQUE NOT NULL DEFAULT '',
  customer_name TEXT,
  warehouse_id UUID REFERENCES public.warehouses(id),
  status TEXT DEFAULT 'Draft' CHECK (status IN ('Draft', 'Waiting', 'Ready', 'Done', 'Canceled')),
  notes TEXT,
  created_by UUID REFERENCES public.profiles(id),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  validated_at TIMESTAMP WITH TIME ZONE
);
ALTER TABLE public.deliveries ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Authenticated users can view deliveries" ON public.deliveries FOR SELECT TO authenticated USING (true);
CREATE POLICY "Authenticated users can insert deliveries" ON public.deliveries FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "Authenticated users can update deliveries" ON public.deliveries FOR UPDATE TO authenticated USING (true);

-- Delivery Items
CREATE TABLE public.delivery_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  delivery_id UUID NOT NULL REFERENCES public.deliveries(id) ON DELETE CASCADE,
  product_id UUID NOT NULL REFERENCES public.products(id),
  requested_qty INTEGER DEFAULT 0,
  delivered_qty INTEGER DEFAULT 0
);
ALTER TABLE public.delivery_items ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Authenticated users can view delivery_items" ON public.delivery_items FOR SELECT TO authenticated USING (true);
CREATE POLICY "Authenticated users can insert delivery_items" ON public.delivery_items FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "Authenticated users can update delivery_items" ON public.delivery_items FOR UPDATE TO authenticated USING (true);
CREATE POLICY "Authenticated users can delete delivery_items" ON public.delivery_items FOR DELETE TO authenticated USING (true);

-- Internal Transfers
CREATE TABLE public.internal_transfers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  reference_no TEXT UNIQUE NOT NULL DEFAULT '',
  from_warehouse_id UUID REFERENCES public.warehouses(id),
  to_warehouse_id UUID REFERENCES public.warehouses(id),
  status TEXT DEFAULT 'Draft' CHECK (status IN ('Draft', 'Waiting', 'Ready', 'Done', 'Canceled')),
  notes TEXT,
  created_by UUID REFERENCES public.profiles(id),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  validated_at TIMESTAMP WITH TIME ZONE
);
ALTER TABLE public.internal_transfers ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Authenticated users can view transfers" ON public.internal_transfers FOR SELECT TO authenticated USING (true);
CREATE POLICY "Authenticated users can insert transfers" ON public.internal_transfers FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "Authenticated users can update transfers" ON public.internal_transfers FOR UPDATE TO authenticated USING (true);

-- Transfer Items
CREATE TABLE public.transfer_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  transfer_id UUID NOT NULL REFERENCES public.internal_transfers(id) ON DELETE CASCADE,
  product_id UUID NOT NULL REFERENCES public.products(id),
  quantity INTEGER DEFAULT 0
);
ALTER TABLE public.transfer_items ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Authenticated users can view transfer_items" ON public.transfer_items FOR SELECT TO authenticated USING (true);
CREATE POLICY "Authenticated users can insert transfer_items" ON public.transfer_items FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "Authenticated users can update transfer_items" ON public.transfer_items FOR UPDATE TO authenticated USING (true);
CREATE POLICY "Authenticated users can delete transfer_items" ON public.transfer_items FOR DELETE TO authenticated USING (true);

-- Stock Adjustments
CREATE TABLE public.stock_adjustments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  reference_no TEXT UNIQUE NOT NULL DEFAULT '',
  warehouse_id UUID REFERENCES public.warehouses(id),
  status TEXT DEFAULT 'Draft' CHECK (status IN ('Draft', 'Done')),
  reason TEXT,
  created_by UUID REFERENCES public.profiles(id),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);
ALTER TABLE public.stock_adjustments ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Authenticated users can view adjustments" ON public.stock_adjustments FOR SELECT TO authenticated USING (true);
CREATE POLICY "Authenticated users can insert adjustments" ON public.stock_adjustments FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "Authenticated users can update adjustments" ON public.stock_adjustments FOR UPDATE TO authenticated USING (true);

-- Adjustment Items
CREATE TABLE public.adjustment_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  adjustment_id UUID NOT NULL REFERENCES public.stock_adjustments(id) ON DELETE CASCADE,
  product_id UUID NOT NULL REFERENCES public.products(id),
  recorded_qty INTEGER DEFAULT 0,
  actual_qty INTEGER DEFAULT 0,
  difference INTEGER GENERATED ALWAYS AS (actual_qty - recorded_qty) STORED
);
ALTER TABLE public.adjustment_items ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Authenticated users can view adjustment_items" ON public.adjustment_items FOR SELECT TO authenticated USING (true);
CREATE POLICY "Authenticated users can insert adjustment_items" ON public.adjustment_items FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "Authenticated users can update adjustment_items" ON public.adjustment_items FOR UPDATE TO authenticated USING (true);
CREATE POLICY "Authenticated users can delete adjustment_items" ON public.adjustment_items FOR DELETE TO authenticated USING (true);

-- Stock Ledger
CREATE TABLE public.stock_ledger (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id UUID NOT NULL REFERENCES public.products(id),
  warehouse_id UUID NOT NULL REFERENCES public.warehouses(id),
  operation_type TEXT NOT NULL CHECK (operation_type IN ('receipt', 'delivery', 'transfer_in', 'transfer_out', 'adjustment')),
  reference_no TEXT NOT NULL,
  quantity_change INTEGER NOT NULL,
  quantity_before INTEGER NOT NULL DEFAULT 0,
  quantity_after INTEGER NOT NULL DEFAULT 0,
  created_by UUID REFERENCES public.profiles(id),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);
ALTER TABLE public.stock_ledger ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Authenticated users can view ledger" ON public.stock_ledger FOR SELECT TO authenticated USING (true);
CREATE POLICY "Authenticated users can insert ledger" ON public.stock_ledger FOR INSERT TO authenticated WITH CHECK (true);

-- Enable realtime on key tables
ALTER PUBLICATION supabase_realtime ADD TABLE public.stock;
ALTER PUBLICATION supabase_realtime ADD TABLE public.receipts;
ALTER PUBLICATION supabase_realtime ADD TABLE public.deliveries;
ALTER PUBLICATION supabase_realtime ADD TABLE public.internal_transfers;

-- Auto reference number generation functions
CREATE OR REPLACE FUNCTION public.generate_receipt_reference()
RETURNS TRIGGER AS $$
DECLARE next_num INTEGER;
BEGIN
  SELECT COALESCE(MAX(CAST(SUBSTRING(reference_no FROM 5) AS INTEGER)), 0) + 1 INTO next_num FROM public.receipts WHERE reference_no != '';
  NEW.reference_no := 'REC-' || LPAD(next_num::TEXT, 4, '0');
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SET search_path = public;

CREATE TRIGGER set_receipt_reference BEFORE INSERT ON public.receipts
  FOR EACH ROW WHEN (NEW.reference_no IS NULL OR NEW.reference_no = '')
  EXECUTE FUNCTION public.generate_receipt_reference();

CREATE OR REPLACE FUNCTION public.generate_delivery_reference()
RETURNS TRIGGER AS $$
DECLARE next_num INTEGER;
BEGIN
  SELECT COALESCE(MAX(CAST(SUBSTRING(reference_no FROM 5) AS INTEGER)), 0) + 1 INTO next_num FROM public.deliveries WHERE reference_no != '';
  NEW.reference_no := 'DEL-' || LPAD(next_num::TEXT, 4, '0');
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SET search_path = public;

CREATE TRIGGER set_delivery_reference BEFORE INSERT ON public.deliveries
  FOR EACH ROW WHEN (NEW.reference_no IS NULL OR NEW.reference_no = '')
  EXECUTE FUNCTION public.generate_delivery_reference();

CREATE OR REPLACE FUNCTION public.generate_transfer_reference()
RETURNS TRIGGER AS $$
DECLARE next_num INTEGER;
BEGIN
  SELECT COALESCE(MAX(CAST(SUBSTRING(reference_no FROM 5) AS INTEGER)), 0) + 1 INTO next_num FROM public.internal_transfers WHERE reference_no != '';
  NEW.reference_no := 'INT-' || LPAD(next_num::TEXT, 4, '0');
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SET search_path = public;

CREATE TRIGGER set_transfer_reference BEFORE INSERT ON public.internal_transfers
  FOR EACH ROW WHEN (NEW.reference_no IS NULL OR NEW.reference_no = '')
  EXECUTE FUNCTION public.generate_transfer_reference();

CREATE OR REPLACE FUNCTION public.generate_adjustment_reference()
RETURNS TRIGGER AS $$
DECLARE next_num INTEGER;
BEGIN
  SELECT COALESCE(MAX(CAST(SUBSTRING(reference_no FROM 5) AS INTEGER)), 0) + 1 INTO next_num FROM public.stock_adjustments WHERE reference_no != '';
  NEW.reference_no := 'ADJ-' || LPAD(next_num::TEXT, 4, '0');
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SET search_path = public;

CREATE TRIGGER set_adjustment_reference BEFORE INSERT ON public.stock_adjustments
  FOR EACH ROW WHEN (NEW.reference_no IS NULL OR NEW.reference_no = '')
  EXECUTE FUNCTION public.generate_adjustment_reference();

-- Validate receipt function
CREATE OR REPLACE FUNCTION public.validate_receipt(p_receipt_id UUID, p_user_id UUID)
RETURNS VOID AS $$
DECLARE
  item RECORD;
  current_qty INTEGER;
  v_warehouse_id UUID;
  v_reference_no TEXT;
BEGIN
  SELECT warehouse_id, reference_no INTO v_warehouse_id, v_reference_no FROM public.receipts WHERE id = p_receipt_id AND status != 'Done' AND status != 'Canceled';
  IF NOT FOUND THEN RAISE EXCEPTION 'Receipt not found or already processed'; END IF;

  FOR item IN SELECT * FROM public.receipt_items WHERE receipt_id = p_receipt_id LOOP
    SELECT COALESCE(quantity, 0) INTO current_qty FROM public.stock WHERE product_id = item.product_id AND warehouse_id = v_warehouse_id;
    IF NOT FOUND THEN current_qty := 0; END IF;
    
    INSERT INTO public.stock (product_id, warehouse_id, quantity, updated_at)
    VALUES (item.product_id, v_warehouse_id, item.received_qty, now())
    ON CONFLICT (product_id, warehouse_id) DO UPDATE SET quantity = stock.quantity + item.received_qty, updated_at = now();

    INSERT INTO public.stock_ledger (product_id, warehouse_id, operation_type, reference_no, quantity_change, quantity_before, quantity_after, created_by)
    VALUES (item.product_id, v_warehouse_id, 'receipt', v_reference_no, item.received_qty, current_qty, current_qty + item.received_qty, p_user_id);
  END LOOP;

  UPDATE public.receipts SET status = 'Done', validated_at = now() WHERE id = p_receipt_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Validate delivery function
CREATE OR REPLACE FUNCTION public.validate_delivery(p_delivery_id UUID, p_user_id UUID)
RETURNS VOID AS $$
DECLARE
  item RECORD;
  current_qty INTEGER;
  v_warehouse_id UUID;
  v_reference_no TEXT;
BEGIN
  SELECT warehouse_id, reference_no INTO v_warehouse_id, v_reference_no FROM public.deliveries WHERE id = p_delivery_id AND status != 'Done' AND status != 'Canceled';
  IF NOT FOUND THEN RAISE EXCEPTION 'Delivery not found or already processed'; END IF;

  FOR item IN SELECT * FROM public.delivery_items WHERE delivery_id = p_delivery_id LOOP
    SELECT COALESCE(quantity, 0) INTO current_qty FROM public.stock WHERE product_id = item.product_id AND warehouse_id = v_warehouse_id;
    IF NOT FOUND THEN current_qty := 0; END IF;
    
    UPDATE public.stock SET quantity = stock.quantity - item.delivered_qty, updated_at = now() WHERE product_id = item.product_id AND warehouse_id = v_warehouse_id;

    INSERT INTO public.stock_ledger (product_id, warehouse_id, operation_type, reference_no, quantity_change, quantity_before, quantity_after, created_by)
    VALUES (item.product_id, v_warehouse_id, 'delivery', v_reference_no, -item.delivered_qty, current_qty, current_qty - item.delivered_qty, p_user_id);
  END LOOP;

  UPDATE public.deliveries SET status = 'Done', validated_at = now() WHERE id = p_delivery_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Validate transfer function
CREATE OR REPLACE FUNCTION public.validate_transfer(p_transfer_id UUID, p_user_id UUID)
RETURNS VOID AS $$
DECLARE
  item RECORD;
  from_qty INTEGER;
  to_qty INTEGER;
  v_from_warehouse_id UUID;
  v_to_warehouse_id UUID;
  v_reference_no TEXT;
BEGIN
  SELECT from_warehouse_id, to_warehouse_id, reference_no INTO v_from_warehouse_id, v_to_warehouse_id, v_reference_no FROM public.internal_transfers WHERE id = p_transfer_id AND status != 'Done' AND status != 'Canceled';
  IF NOT FOUND THEN RAISE EXCEPTION 'Transfer not found or already processed'; END IF;

  FOR item IN SELECT * FROM public.transfer_items WHERE transfer_id = p_transfer_id LOOP
    SELECT COALESCE(quantity, 0) INTO from_qty FROM public.stock WHERE product_id = item.product_id AND warehouse_id = v_from_warehouse_id;
    IF NOT FOUND THEN from_qty := 0; END IF;
    SELECT COALESCE(quantity, 0) INTO to_qty FROM public.stock WHERE product_id = item.product_id AND warehouse_id = v_to_warehouse_id;
    IF NOT FOUND THEN to_qty := 0; END IF;
    
    UPDATE public.stock SET quantity = stock.quantity - item.quantity, updated_at = now() WHERE product_id = item.product_id AND warehouse_id = v_from_warehouse_id;
    
    INSERT INTO public.stock (product_id, warehouse_id, quantity, updated_at)
    VALUES (item.product_id, v_to_warehouse_id, item.quantity, now())
    ON CONFLICT (product_id, warehouse_id) DO UPDATE SET quantity = stock.quantity + item.quantity, updated_at = now();

    INSERT INTO public.stock_ledger (product_id, warehouse_id, operation_type, reference_no, quantity_change, quantity_before, quantity_after, created_by)
    VALUES (item.product_id, v_from_warehouse_id, 'transfer_out', v_reference_no, -item.quantity, from_qty, from_qty - item.quantity, p_user_id);
    
    INSERT INTO public.stock_ledger (product_id, warehouse_id, operation_type, reference_no, quantity_change, quantity_before, quantity_after, created_by)
    VALUES (item.product_id, v_to_warehouse_id, 'transfer_in', v_reference_no, item.quantity, to_qty, to_qty + item.quantity, p_user_id);
  END LOOP;

  UPDATE public.internal_transfers SET status = 'Done', validated_at = now() WHERE id = p_transfer_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Validate adjustment function
CREATE OR REPLACE FUNCTION public.validate_adjustment(p_adjustment_id UUID, p_user_id UUID)
RETURNS VOID AS $$
DECLARE
  item RECORD;
  current_qty INTEGER;
  v_warehouse_id UUID;
  v_reference_no TEXT;
BEGIN
  SELECT warehouse_id, reference_no INTO v_warehouse_id, v_reference_no FROM public.stock_adjustments WHERE id = p_adjustment_id AND status != 'Done';
  IF NOT FOUND THEN RAISE EXCEPTION 'Adjustment not found or already processed'; END IF;

  FOR item IN SELECT * FROM public.adjustment_items WHERE adjustment_id = p_adjustment_id LOOP
    SELECT COALESCE(quantity, 0) INTO current_qty FROM public.stock WHERE product_id = item.product_id AND warehouse_id = v_warehouse_id;
    IF NOT FOUND THEN current_qty := 0; END IF;
    
    INSERT INTO public.stock (product_id, warehouse_id, quantity, updated_at)
    VALUES (item.product_id, v_warehouse_id, item.actual_qty, now())
    ON CONFLICT (product_id, warehouse_id) DO UPDATE SET quantity = item.actual_qty, updated_at = now();

    INSERT INTO public.stock_ledger (product_id, warehouse_id, operation_type, reference_no, quantity_change, quantity_before, quantity_after, created_by)
    VALUES (item.product_id, v_warehouse_id, 'adjustment', v_reference_no, item.actual_qty - current_qty, current_qty, item.actual_qty, p_user_id);
  END LOOP;

  UPDATE public.stock_adjustments SET status = 'Done' WHERE id = p_adjustment_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;
