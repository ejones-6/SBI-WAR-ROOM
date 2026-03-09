-- ================================================================
-- StoneBridge War Room — Supabase Migration
-- Run this entire file once in: Supabase Dashboard → SQL Editor
-- ================================================================

-- ── Enable UUID extension ────────────────────────────────────────
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ── DEALS ────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS deals (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name            TEXT NOT NULL UNIQUE,
  status          TEXT NOT NULL DEFAULT '1 - New',
  market          TEXT,
  units           INTEGER,
  year_built      INTEGER,
  price_per_unit  BIGINT,
  purchase_price  BIGINT,
  bid_due_date    DATE,
  added           DATE,
  modified        DATE,
  comments        TEXT,
  flagged         BOOLEAN DEFAULT FALSE,
  hot             BOOLEAN DEFAULT FALSE,
  broker          TEXT,
  buyer           TEXT,
  seller          TEXT,
  sold_price      BIGINT,
  created_at      TIMESTAMPTZ DEFAULT NOW(),
  updated_at      TIMESTAMPTZ DEFAULT NOW()
);

-- ── BOE DATA ─────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS boe_data (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  deal_name   TEXT NOT NULL UNIQUE REFERENCES deals(name) ON UPDATE CASCADE ON DELETE CASCADE,
  t12         JSONB NOT NULL DEFAULT '{}',
  adjs        JSONB NOT NULL DEFAULT '{}',
  notes       JSONB NOT NULL DEFAULT '{}',
  payroll     JSONB NOT NULL DEFAULT '{}',
  rmi         JSONB NOT NULL DEFAULT '{}',
  tax_helper  JSONB NOT NULL DEFAULT '{}',
  period      TEXT,
  updated_at  TIMESTAMPTZ DEFAULT NOW()
);

-- ── CAP RATES ────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS cap_rates (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  deal_name        TEXT NOT NULL UNIQUE REFERENCES deals(name) ON UPDATE CASCADE ON DELETE CASCADE,
  broker_cap_rate  NUMERIC(6,3),
  noi_cap_rate     NUMERIC(6,3),
  purchase_price   BIGINT,
  sold_price       BIGINT,
  delta            NUMERIC(8,4),
  updated_at       TIMESTAMPTZ DEFAULT NOW()
);

-- ── USER PROFILES ────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS user_profiles (
  id         UUID PRIMARY KEY REFERENCES auth.users ON DELETE CASCADE,
  email      TEXT,
  full_name  TEXT,
  role       TEXT DEFAULT 'analyst' CHECK (role IN ('admin','analyst','viewer')),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Auto-create profile on signup
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  INSERT INTO user_profiles (id, email, full_name)
  VALUES (NEW.id, NEW.email, NEW.raw_user_meta_data->>'full_name')
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE PROCEDURE handle_new_user();

-- ── UPDATED_AT TRIGGER ───────────────────────────────────────────
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN NEW.updated_at = NOW(); RETURN NEW; END;
$$;

DROP TRIGGER IF EXISTS set_deals_updated_at ON deals;
CREATE TRIGGER set_deals_updated_at BEFORE UPDATE ON deals
  FOR EACH ROW EXECUTE PROCEDURE update_updated_at();

DROP TRIGGER IF EXISTS set_boe_updated_at ON boe_data;
CREATE TRIGGER set_boe_updated_at BEFORE UPDATE ON boe_data
  FOR EACH ROW EXECUTE PROCEDURE update_updated_at();

DROP TRIGGER IF EXISTS set_cap_rates_updated_at ON cap_rates;
CREATE TRIGGER set_cap_rates_updated_at BEFORE UPDATE ON cap_rates
  FOR EACH ROW EXECUTE PROCEDURE update_updated_at();

-- ── ROW LEVEL SECURITY ───────────────────────────────────────────
ALTER TABLE deals         ENABLE ROW LEVEL SECURITY;
ALTER TABLE boe_data      ENABLE ROW LEVEL SECURITY;
ALTER TABLE cap_rates     ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;

-- All authenticated users can read everything
CREATE POLICY "auth_read_deals"    ON deals         FOR SELECT TO authenticated USING (true);
CREATE POLICY "auth_read_boe"      ON boe_data      FOR SELECT TO authenticated USING (true);
CREATE POLICY "auth_read_cap"      ON cap_rates     FOR SELECT TO authenticated USING (true);
CREATE POLICY "auth_read_profiles" ON user_profiles FOR SELECT TO authenticated USING (true);

-- All authenticated users can insert/update/delete
CREATE POLICY "auth_write_deals"   ON deals         FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "auth_write_boe"     ON boe_data      FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "auth_write_cap"     ON cap_rates     FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "auth_write_profiles" ON user_profiles FOR ALL TO authenticated USING (auth.uid() = id) WITH CHECK (auth.uid() = id);

-- ── INDEXES ──────────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_deals_status   ON deals(status);
CREATE INDEX IF NOT EXISTS idx_deals_market   ON deals(market);
CREATE INDEX IF NOT EXISTS idx_deals_modified ON deals(modified DESC);
CREATE INDEX IF NOT EXISTS idx_deals_name     ON deals(name);

-- ================================================================
-- SEED: 2,009 deals from the existing War Room
-- ================================================================

INSERT INTO deals (name,status,market,units,year_built,price_per_unit,purchase_price,bid_due_date,added,modified,comments,flagged,hot,broker) VALUES
('Highland at Park Lake','1 - New','Orlando, FL',21,2023,642857,13500000,NULL,'2026-02-11','2026-03-05','All Docs Saved 13.5-14M Bain/Acasa taking a loss

JS: Nice deal and location but very small, not sure of economics, too small',TRUE,TRUE,'Berkadia'),
('South Pointe Apartments','1 - New','Miami, FL',251,2017,298805,75000000,NULL,'2026-02-10','2026-03-05','All Docs Saved - 75M - Now whisper is 65M 3/5/26 EJ',TRUE,TRUE,'Rosewood'),
('Sunset Lakes BTR Forward Sale','1 - New','Chattanooga, TN-GA',190,2026,315789,60000000,'2026-03-24','2026-02-10','2026-03-05','All Docs Saved - 
Hi Ethan, 

Hope all is well.

Thank you for your interest in Sunset Lakes, a to-be-developed Class A+ Build-To- Rent (BTR) single-family home community located in rapidly expanding Harrison, TN, in the Chattanooga MSA.  The Property will consist of 190 two-story single-family homes featuring spacious 3-, 4-, and 5-bedroom floorplans averaging 1,840 square feet.  All homes will feature attached two-car garages, top-of-market interior finishes, smart home technology packages, an',FALSE,FALSE,'C&W'),
('Blakeney Commons','1 - New','Nashville, TN',80,2024,333750,26700000,'2026-03-10','2026-02-26','2026-03-05','All Docs Saved - Blakeney Commons (2024 | 80 Townhomes)
•	Guidance: ~$26.7MM (~$335K/unit)
•	Cap Rate: ~5.5% (Yr. 1)
 
Investment Highlights
•	Class A product offered well below replacement cost
•	Discount to Retail Sales ($420K Median Sale Price - 37167 Zip Code)
•	Access to Tennessee''s Top Employment Corridor
•	Zero Supply Within a 5-Mile Radius
•	Outstanding Property Demographics
•	Access to Top Tier Schools
•	Full suite of community amenities (32 1-Car Garages, Dog Park, Playground, Private ',TRUE,TRUE,'JLL'),
('Beckington Townhomes','1 - New','Wilmington, NC',143,2024,265734,38000000,NULL,'2026-03-05','2026-03-05','All Docs Saved - EJ - Prob not for us but wanted to see if this team had anything interesting
Ethan, 
 
Per Hunter’s previous email, I wanted to shoot you over the details on Beckington Townhomes in the Wilmington, NC MSA. 
 
The owners are a family office developer out of PA who tried to self manage. With little experience in NC and being their only property in the region, they straggled with lease up which had a pretty hard hit on rents and lowered them to get the property where it is now. The',TRUE,TRUE,'C&W'),
('Valencia at Westchase','1 - New','Tampa-St. Petersburg-Clearwater, FL',312,1996,214744,67000000,NULL,'2026-03-05','2026-03-05','All Docs Saved - Ethan,
 
Thanks for your interest in Valencia at Westchase, 312 units located in the Town “n” Country submarket of Tampa, FL which has very little new supply coming online in the vicinity and projected 11% rent growth in the next five years.
 
Valencia at Westchase is a 1996/1997 vintage gated community with a balanced mix of 50% one-bedrooms, 27% two-bedrooms and 23% three-bedrooms with an average unit size of 980 SF. The property boasts a clubhouse, fitness center, swimming po',FALSE,FALSE,'C&W'),
('Mainstreet at Conyers','1 - New','Atlanta, GA',192,2000,NULL,'',NULL,'2026-03-05','2026-03-05','No Docs yet signed CA',FALSE,FALSE,'Berkadia'),
('Dayrise at Centreport','1 - New','Fort Worth, TX',344,2012,203488,70000000,NULL,'2026-03-04','2026-03-05','All Docs Saved Low to mid 70''s',FALSE,FALSE,'CBRE'),
('Lyra on McKinney','1 - New','Dallas-Fort Worth, TX',190,2017,292105,55500000,NULL,'2026-03-04','2026-03-05','All Docs Saved - 55.5',TRUE,TRUE,'CBRE'),
('Ranch Lake','1 - New','Sarasota-Bradenton, FL',336,2014,238095,80000000,NULL,'2026-02-13','2026-03-04','All Docs Saved Hey Ethan,
The pricing guidance is in the low $80mm’s (low $240,000’s per unit).  This yields an in-place cap rate in the 5.25% range (T3 revenues with adjusted expenses).   As you dig in, you will want to take note of the following: 
•	The current owners are the original developers and they self-manage.   For tax purposes, they have been running certain expenses through opex that most institutional owners would keep below the line.   Some of these adjustments will be noted in the',FALSE,FALSE,'Berkadia'),
('TRELLIS HERNDON Apartments','1 - New','Washington, DC-MD-VA',168,2024,273810,46000000,'2026-03-18','2025-04-01','2026-03-04','All Docs Saved - 


Will, guiding to $46M, 5.3% in-place cap.



Berkadia Ethan,

Thanks for reaching out. Guidance is $48m-$50m which is a 5% in place cap rate adjusted for PF other income and Opex. Able to get to 5.5% to 5.75% PF cap rate with the mark to market potential – all utilities (including cable/internet) included in rents which presents a lot of headroom on market rents which are already below comps, WDU’s (which is 50% of units) are 7.5% below max allowable rents, can begin reimburs',TRUE,TRUE,'W&D'),
('Tortuga Pointe by ARIUM','1 - New','Tampa-St. Petersburg-Clearwater, FL',295,2010,267797,79000000,'2026-03-11','2026-02-26','2026-03-04','All Docs Saved - Ethan,
My apologies, I missed your note. I just tried to give you a shout. We’re guiding to $270k/unit here. Let me know if you’d like to hop on a call to discuss.
',TRUE,TRUE,'CBRE'),
('Creekview Vista Apartments','1 - New','',279,2024,200717,56000000,NULL,'2026-03-03','2026-03-04','All Docs saved - Thanks for your note. Guidance on Creekview is $200K/unit, or ~$56M which will translate to a 5.50%+ cap. It’s fully stabilized new construction product that should outperform due to the product quality, proximity to I-85 and a rapidly stabilizing submarket supply pipeline. 

LaGrange has a well-rounded economic development narrative which is supported by:
•	Manufacturing/Distribution (Kia, Hyundai, Duracell, and Remington)
•	Tourism (Callaway Gardens/Great Wolf Lodge) 
•	Health',FALSE,FALSE,'W&D'),
('Stillwater at Grandview Cove','1 - New','Greenville-Spartanburg-Anderson, SC',240,1989,160000,38400000,NULL,'2026-03-03','2026-03-04','All Docs Saved - •	Guidance is $160k - $165k/door which is a mid 5% in place with full taxes and north of a 6% if a tax abatement strategy is pursued. 
•	Renewals have been averaging 3.5% over the past 12 months with a really strong retention ratio around 70%. 
•	In-place rents on the current RR have increased to $1,321 from $1,289 a year prior.
•	All units have been renovated to the same scope
•	Potential upgrades include:
o	Adding W/Ds to all units (all units currently have connections
o	Addin',FALSE,FALSE,'Newmark'),
('Las Palmas','1 - New','Orlando, FL',250,1974,160000,40000000,NULL,'2026-02-26','2026-03-03','All Docs Saved - Ethan,
 
Thank you for your interest in Las Palmas in Altamonte Springs, Florida. The offering represents the opportunity to acquire a turnkey light value-add community in one of Orlando‘s most desirable and affluent submarkets. The property was built in 1974 and features a balanced mix of one- and two-bedroom floorplans, many of which are outsized for the submarket. Furthermore, the units feature competitive amenities such as washer dryers in all units, as well as screened-in p',TRUE,TRUE,'C&W'),
('Triton Cay - Orlando','1 - New','Orlando, FL',342,2022,263158,90000000,NULL,'2026-02-26','2026-03-03','All Docs Saved - Hi Ethan.  Will is traveling but below is a high-level deal narrative and then we’re happy to jump on a call to discuss further.  At $263k per door this is an incredible basis play for new, 4-5 story wrap product.

Triton Cay Orlando is a 342-unit core asset located in one of the most dynamic pockets of Orlando, the #1 fastest-growing MSA in the United States. Built in 2022, the property is 100% market-rate and offers first-class unit finishes and resort-inspired amenities that ',TRUE,TRUE,'Colliers'),
('Highland Mill Lofts','1 - New','Charlotte-Gastonia-Rock Hill, NC-SC',166,19042007,277108,46000000,NULL,'2026-02-26','2026-03-03','All Docs Saved -No OM - EJ - theres retail here - $46m is guidance on Highland Mill. 50% perpetual tax abatement and ~10k of retail bring net/comparative per unit down to 220s-230. ',FALSE,FALSE,'Newmark'),
('Orchid Run','1 - New','Naples, FL',282,2015,322695,91000000,'2026-03-19','2026-02-12','2026-03-03','All Docs Saved

JS: too large

  - Hey Ethan,

Thanks for reaching out. Pricing guidance for Orchid Run is ~$91.65 million which is $325,000/unit. That translates to an ~5.2% in-place cap rate (T3 rev/tax adj. year 1 expense). If you mark occupancy to 95% and burn-off the in-place concessions, the in-place cap rate increases to ~5.75%+.

Orchid Run is a 2015-vintage, 282-unit community and represents a rare institutional-grade asset in one of the nation’s most affluent and supply-constrained mar',TRUE,TRUE,'Berkadia'),
('Chesterfield Flats','1 - New','Richmond-Petersburg, VA',278,1978,169065,47000000,NULL,'2026-02-26','2026-03-02','All Docs Saved - Chesterfield Flats presents the opportunity to achieve immediate scale in the high-demand Chesterfield County submarket. Ownership has already spent $6.2 million in capital improvements to the property. With nearly ~50% of the property having been renovated and achieving rental premiums up to $285 per unit, we believe there is an estimated $411,000 in additional income left to be realized through renovations alone, excluding some expense savings and other income items to impleme',TRUE,TRUE,'Berkadia'),
('Reserve Bartram Springs','1 - New','Jacksonville, FL',268,2006,184701,49500000,NULL,'2026-02-26','2026-03-02','All Docs Saved - No OM - Hi Ethan - See below and let me know if you need anything else.

•	Targeting mid to upper 180s per unit range
•	6% rent growth on renewals
•	Tapering supply (only 1 deal in lease-up and below 80% occupancy) 
•	Avg HHI $173k within a 5-mile radius
•	193% population growth within 5-mile radius in las 10 years
•	Zoned for “A” rated schools
•	124 units have been renovated and are achieving an average premium of $150
',TRUE,TRUE,'W&D'),
('The Fields Conover Apartments Homes','1 - New','Hickory-Morganton-Lenoir, NC',160,2000,153125,24500000,NULL,'2026-02-26','2026-03-02','All Docs Saved  no OM  - Low - mid $150ks/door on conover ',TRUE,TRUE,'Newmark'),
('Andover Park apartments','1 - New','Greensboro--Winston-Salem--High Point, NC',120,2007,160000,19200000,NULL,'2026-02-26','2026-03-02','All Docs Saved no OM - Low $160ks/door on Andover Park ',TRUE,TRUE,'Newmark'),
('Sixty11th Luxury Midtown Apartments','1 - New','Atlanta, GA',320,2016,375000,120000000,NULL,'2026-02-26','2026-03-02','All Docs saved - We’re guiding $375K per unit on the residential and $10-11M on the 16K SF of retail, for a total deal size just north of $130M. The asset has proven highly resilient through the recent supply wave and is currently 94-95% leased with rents trending upward.  Large average unit sizes (~950SF), strong amenity programming, and a central Midtown location have supported ~70% retention.

There is a compelling, low-risk value-add component.  Ownership has already tested appliance upgrade',TRUE,FALSE,''),
('Alta Porter on Peachtree','1 - New','Atlanta, GA',291,2023,347079,101000000,NULL,'2026-02-24','2026-03-02','All Docs Saved no OM - Likewise! Price guidance is low-$100Ms, which is $350k-$360k/u and well below replacement cost.',TRUE,TRUE,'CBRE'),
('Ascend Ridgewood Lakes','1 - New','Lakeland-Winter Haven, FL',240,2024,NULL,'',NULL,'2026-03-02','2026-03-02','Coming Soon',FALSE,FALSE,'Berkadia'),
('Ascend Waterleigh Village','1 - New','Orlando, FL',280,2024,303571,85000000,NULL,'2026-02-25','2026-02-27','All Docs saved - Ethan,

Guidance on Ascend Waterleigh Village is $85M or around $300K per door, which is a low 5% Yr. 1 cap rate including some upfront concessions as the property completes its lease up.  As you start to pull back on concessions in Yr. 2, the cap rate moves to a mid 5%.

Ascend Waterleigh Village is a newly built, 280-unit, elevator-serviced asset featuring interior air-conditioned corridors, one of the only assets in Horizon West to offer conditioned corridors. The property ha',TRUE,FALSE,'Newmark'),
('Longhorn Crossing Apartments','1 - New','Fort Worth, TX',240,2016,204167,49000000,'2026-03-12','2026-02-18','2026-02-26','All Docs Saved

Nice looking deal, size, location etc. but don''t see any value-add here. Nothing in OM and units look good, flooring looks to be done already etc.

 - Ethan, 

Hope all is well. Guidance pricing here is $49m, let us know if you have any questions or need additional information. 
',TRUE,TRUE,'Newmark'),
('Sands Parc Apartments','1 - New','DaytonaBeach, FL',264,2017,208333,55000000,'2026-03-17','2026-02-05','2026-02-25','All Docs Saved

JS: light value-add in daytona beach, good size, location looks good (for daytona beach)

 - Ask is around $55M, $205-210K per door and a low 5% on trailing, tax adjusted numbers.

Great basis for this vintage/quality product and there''s a lot of upside in the rents due to all of the growth that has continued to come into the Daytona Market. Since 2022, there have been 2,000+ units that have delivered in the immediate area that the property has had to compete with. The good news ',TRUE,TRUE,'Newmark'),
('Solana Vista','1 - New','Sarasota-Bradenton, FL',200,1984,220000,44000000,'2026-03-10','2026-01-27','2026-02-24','All Docs Saved 

JS: location looks ok, not super nice area but built out, lots of retail (walmart, golden coral etc.), need more info on price and va

Pricing guidance is $44MM or $220k/unit.

 

Here’s the high-level story: Fantastic opportunity to acquire a stabilized, cash-flowing asset with proven value-add potential in a highly desirable infill area. Recently implemented fees will continue to work their way through the rent roll yielding an additional $53K in annual income. The Property ha',TRUE,TRUE,'JBM'),
('Yardly Crossings','1 - New','DaytonaBeach, FL',233,2025,278970,65000000,NULL,'2026-02-24','2026-02-24','All Docs Saved

JS: near deland/orange city, right off i-4 inbetween orlando and daytona, this could be a good location for btr due to cost alt prox to orlando via -i4. need to look at cost to buy vs rent, seems overpriced though based on pf 4.1 cap

 - Thank you for your interest in Yardly Crossings, a 233-home, Build-to-Rent community built in 2025 by Taylor Morrison (RCM: CA Deal Room Link), one of the nation’s most trusted home builders (NYSE: TMHC). Yardly Crossings is a newly constructed, ',TRUE,TRUE,'Northmarq'),
('Kimmerly Glen Apartments','1 - New','Charlotte-Gastonia-Rock Hill, NC-SC',260,1986,169231,44000000,'2026-03-12','2026-02-10','2026-02-24','All Docs saved  Low $170ks/door - 

JS: east clt, location looks a little dated and rough',TRUE,TRUE,'Newmark'),
('Bell Annapolis on West Apartments','1 - New','Baltimore, MD',300,2007,326667,98000000,NULL,'2026-02-17','2026-02-24','All Docs Saved  - $98M ($325kpu) 
5.6% Cap in-place 

All units are candidate for value-add + 18 ADU Units expire July 26, 2026. 
',TRUE,TRUE,'CBRE'),
('Fox Glen - Homes for Rent','1 - New','Melbourne-Titusville-Palm Bay, FL',100,2023,NULL,'',NULL,'2026-02-13','2026-02-24','All Docs saved - need new docs

JS: sent from Brunmar, sounds like this never traded and is still available (was marketed ~1 yr ago)',TRUE,TRUE,''),
('Ibis Park at Harmony West - Homes for Rent','1 - New','Orlando, FL',101,2024,297030,30000000,NULL,'2026-02-17','2026-02-24','JS: sent from Brunmar, they are looking at this with another equity partner, could fall through...

As discussed, we have been tracking Ibis Park in St. Cloud for quite a while. DR Horton has quietly had this deal on the market for 18 months (and have now asked Berkadia to selectively shop as well in Q1). The asking price fluctuated between $340-350k during that entire time. However, three weeks ago, DRH told me that they’d be willing to sell for $300k if they could get the deal off of their boo',FALSE,FALSE,''),
('Oaks at Oxon Hill Apartments','1 - New','Washington, DC-MD-VA',488,1963,133197,65000000,NULL,'2025-05-05','2026-02-24','All Docs Saved - Was with Transwestern, now CBRE
$65M – 6.75% Cap in-place. 

Ethan,

We expect pricing in the low to mid $150k’s per unit or higher.  This is around a 6% cap on in-place and over a 6.5% cap on year one proforma.  The current rents at the property are well below the rent comps and the property has strong rent growth potential with renewals in the 5% plus range.

A handful of highlights on the opportunity are below:
•	Tremendous asset preservation completed by current and prior ow',TRUE,TRUE,'CBRE'),
('The Grand Reserve at Spring Hill','1 - New','',440,2015,272727,120000000,'2026-03-10','2026-01-30','2026-02-19','
JS: Spring Hill could be interesting (65 corridor south of franklin, but too big...) good to track

Ethan, sorry for the delay getting back to you; just playing catch up from NMHC.

I’m excited about Grand Reserve given the quality, vintage, value-add opportunity, and proximity to Franklin/Cool Springs – you can hit a good tee shot from the back of the property into Williamson Co.  So, this should check a lot of boxes for value-add buyers looking to make a splash in Nashville.  
Here are the qu',TRUE,TRUE,'Newmark'),
('Cortland on Orange','1 - New','Orlando, FL',300,2019,283333,85000000,'2026-03-10','2025-05-13','2026-02-18','All Docs Saved - Ethan,
We’re guiding to $285k/unit on this one. Let me know when you have time to discuss


2025 - Ethan…they can be split up. Target on Hollywood is $121mn and $85mn on Orange. Thanks.  ',TRUE,TRUE,'CBRE'),
('Grand Preserve','1 - New','Athens, GA',232,2025,250000,58000000,NULL,'2026-02-10','2026-02-17','All Docs Saved - Hi Ethan and team,

Thanks for reaching out on this one.  We’re not sure where this one will land just yet but I would pencil in around $58M +/- for now.  Here is some additional color and a refresher on what we discussed for your team.

In the meantime, here is some additional color on the deal. 

Link to Grand Preserve OM & DD Files ? Grand Preserve Landing Page

Grand Preserve – 232 Units – 2025 Completion

-	Built and operated by family owned, local developer with over 40 ye',TRUE,TRUE,'GREA'),
('Sunset BTR','1 - New','Charlotte-Gastonia-Rock Hill, NC-SC',190,'',342105,65000000,NULL,'2026-01-22','2026-02-12','From Chris Love Development $23MM Equity Check

JS Notes:
-	Oakland North Neighborhood
o	Zillow Research
?	Comparable for sale in $250k-$350k depending on vintage and TH / Detached
?	TH: New 3bd ~1,500 SF $280k-$300k range
•	Does not seem to support our basis…
?	Rent of $2,625 for 3bd ~1,500 SF also does not seem to be supported
•	For example, can rent a 2,300 SF 4bd new looking home for $2,450 (1510 gutter branch drive)

-	Basis = $65M / 190 units = $342k / TH
-	Proforma Rents:
o	3bd/ 2b = $2,6',FALSE,FALSE,''),
('3801 Connecticut Avenue','1 - New','Washington, DC-MD-VA',307,1951,205212,63000000,'2026-03-11','2025-09-16','2026-02-11','All Docs Saved

JS: part of elme portfolio, conn ave, new pricing, this one has small units...

 - Both are $63M and ~6.6% Cap in-place (T3 / T12). 
From JLL - 3801 Connecticut - mid $70MMs, ~$240K/Unit, upper-5% to 6% in place tax adjusted cap rate
',TRUE,FALSE,'CBRE'),
('Kenmore','1 - New','Washington, DC-MD-VA',371,1948,169811,63000000,'2026-03-11','2025-09-16','2026-02-10','All Docs Saved

JS: part of elme portfolio, conn ave, new pricing

 - Both are $63M and ~6.6% Cap in-place (T3 / T12). 
From JLL - 	Kenmore – mid $70MMs, ~$200K/Unit, upper-5% to 6% in place tax adjusted cap rate

',TRUE,FALSE,'CBRE'),
('Fox Crossing Apartments','1 - New','Raleigh-Durham-Chapel Hill, NC',168,2024,261905,44000000,'2026-03-10','2026-02-03','2026-02-10','All Docs Saved

JS: no sure about location, maybe too newly built?, sounds like 75% tax abatement in place, base had out last yr for 43M

 - Thanks for the interest in Fox Crossing (website): https://properties.berkadia.com/fox-crossing-486302/?src=src5

•	Pricing: $44M, which is $262k/unit. This equates to a 5.96% Year 1 cap rate, using in-place rents and stabilized expenses with a 75% property tax abatement. (Without the property tax abatement, cap rate is 5.42%.)
•	Doc Center: Link to OM, fin',TRUE,TRUE,'Berkadia'),
('Lennar at Elm Grove','1 - New','Raleigh-Durham-Chapel Hill, NC',78,2026,319231,24900000,NULL,'2026-02-05','2026-02-09','All Docs Saved

JS: 78 unit BTR forward sale JV opportunity. req ~11M equity, all up-front, refi after two years, full sale in 5? a little confused how this works in conjunction with IM pg 37, are we doing two loans?. sourced from ex-employee now at lennar. aggresive lease up? lease up below market then mark to market could be difficult? rent growth fairly strong. expenses felt reasonable. not sure about virtual leasing reliance  

 Gents – Great seeing you today, I enjoyed catching up over lunc',FALSE,FALSE,'Newmark'),
('Project Sunshine','1 - New','Washington, DC-MD-VA',1,1,NULL,'',NULL,'2026-02-02','2026-02-02','15 REO / Sub performing Loans throughout sunbelt markets',FALSE,FALSE,'Eastdil'),
('Lakeside at Arbor Place','2 - Active','Atlanta, GA',246,1996,158537,39000000,NULL,'2026-02-12','2026-03-05','All Docs Saved

JS: pretty far west of atl, good size and 100% value-add, not sure of location

 - Ethan - Thank you for reaching out. Guidance here is $160-170k/unit which is a 5.75%-6.00% tax adjusted, in-place cap rate with the ability to be > 7.00% through strategic value-add. 
 
Here are some quick highlights:
•	Institutionally Maintained: Fogelman has owned the property since 2019 and has maintained it in excellent condition.
•	100% Value-Add Opportunity: 30% Classic units, 70% previously ',TRUE,TRUE,'C&W'),
('Dorsey Overlook Townhomes','2 - Active','Baltimore, MD',78,2024,589744,46000000,NULL,'2026-02-17','2026-03-04','All Docs Saved 

JS: could be interesting, 78 units may be tough

- ·       78 BTR Townhomes in Ellicott City, MD| Built in 2024 | Managed by NewCastle Management Group.
·       Rare opportunity to acquire an institutional-quality Build-to-Rent Asset located in Howard County, MD, rated #1 on Niche.com’s 2025 list of “Best Counties to Live in.”
·       Developed and managed by NewCastle Development (Charlottesville, VA), Dorsey Overlook is the only Build-to-Rent Community in Howard County, MD.
· ',TRUE,TRUE,'Northmarq'),
('Horizon at Premier','2 - Active','Dallas-Fort Worth, TX',122,2017,278689,34000000,'2026-03-24','2026-02-17','2026-03-04','All Docs Saved

JS: BTR, looks like good, location, size, vintage, could be interesting, 5 cap on pf, is this cottage style?

 - Hey Ethan,
We expect Horizon at Premier to trade around $34M–$35M range ($287K–$295K per unit).
The offering represents an opportunity to buy the most infill build-to-rent asset in the DFW metroplex.
•	122 single family homes for rent – no shared walls, all units have private yards
•	Currently 93% occupied and 95% leased, with concessions limited to 2–4 weeks on the Ha',TRUE,TRUE,'IPA'),
('Cortland Peachtree Corners','2 - Active','Atlanta, GA',296,2018,250000,74000000,'2026-03-05','2026-01-23','2026-03-04','All Docs Saved - Ethan-

We priced CPC from $250,000-$255,000/door. Low end is going-in, tax adjusted, 5.15% cap.  
Couple of things to note:

Financial--
1.	Cortland has "MOSS Expenses" that don''t apply to next buyer, you need to pull those out.
2.	Has "Light touch" upgrade opportunity providing $75-$100 premium in rents.
3.	Supply constrained submarket, only 2 other deals built in 25 years. 
4.	CPC''s only 2 competitors have rents $375 higher than CPC
5.	Return to peak rent story = 4% upside.  ',TRUE,TRUE,'Newmark'),
('Atlantic Bridgemill','2 - Active','Atlanta, GA',236,2000,211864,50000000,'2026-03-10','2026-02-03','2026-03-04','All Docs Saved - Ethan,

Thank you for your interest in Atlantic BridgeMill Apartments. The property has excellent curb appeal and an attractive site layout with gated access and clubhouse  – while surrounded by high end suburban homes and the notable BridgeMill Subdivision and Golf Course. With outstanding demos, the property’s most interesting feature may be its walkability to the primary and middle schools next door. 

Ownership upgraded the units seven years ago but there is a bit more that ',TRUE,TRUE,'CBRE'),
('The Hamptons at Woodland Pointe Apartments','2 - Active','Nashville, TN',240,2001,229167,55000000,'2026-03-17','2026-02-11','2026-03-02','All Docs Saved - Ethan, 

Pencil in $55/56MM as a starting point. The T12, cleaned up NOI is around $2.9M. Inplace rents are $1,755 and the property runs on LRO with no concessions, with 5-6% vacancy over the T12 . There are 120 attached garages assigned to specific units, and the rent for those units includes the garage without any separate fee. 

Let me know if you have any questions. I’d anticipate we send out the OM and #s next week. 
',TRUE,FALSE,'W&D'),
('Savona Grand Apartments','2 - Active','West Palm Beach-Boca Raton, FL',214,2003,308411,66000000,'2026-03-19','2026-02-10','2026-02-27','All Docs Saved

JS: could be interesting, south of boatman, looks like better location, retail looks ok and sf is much better than boatman, large gated community adjacent to apts
Target pricing is $310k per unit, 5 cap.  Highly desirable vintage with 9-foot ceilings and great bones, just needs a thorough refresh.  Can we get a tour set up?',TRUE,FALSE,'Newmark'),
('ShoreView Waterfront Apartments','2 - Active','Sarasota-Bradenton, FL',216,2021,268519,58000000,'2026-03-09','2026-02-13','2026-02-26','All Docs Saved

JS: could be interesting, does not sound like a ton of value add but looks like an interesting location and supply story

 - mezz-lender foreclosure.  Located directly on the Riverwalk in downtown Bradenton.
Thanks for reaching out.   We’re expecting pricing of $58 million ($268,500 per unit), which yields a 5.25% in-place cap rate (T3 revenue/Yr1 expense with taxes reflecting the LLA tax abatement).    This is a compelling basis below replacement cost.   Furthermore, as a point ',TRUE,TRUE,'Berkadia'),
('Gwinnett BFR Portfolio','2 - Active','Atlanta, GA',202,1984,143564,29000000,'2026-03-10','2026-02-05','2026-02-25','All Docs Saved - Ethan,

Thanks for reaching out. Guidance for the portfolio is $145k to $150k PU. This a highly unique offering of low density BFR product spread across 3 properties located in Lawrenceville (Anaberry) and Norcross (Tanaga and Green Hill). The properties are still owned and operated by the original developer from back in the 80’s and have substantial operational and value add upside as the unit interiors are essentially original. They are located within their own subdivisions in',TRUE,FALSE,'W&D'),
('Palisades at Manassas Park','10 - Owned Property','Washington, DC-MD-VA',304,2016,280592,85300000,'2024-02-22','2023-04-24','2026-02-09','all docs saved
back on market Feb 2023
talked to Bill 7.5, they had 3 groups in BAF one at 82M but seller is holding out for 83M
all docs saved
next to VRE
We are looking for mid to upper 80s which is around a 5 cap in a market that has shown a lot of upside.  Additionally, because of the location, the deal qualifies for Mission pricing from the agencies, so the debt is pretty attractive',TRUE,FALSE,NULL),
('Briarhill Apartments','2 - Active','Atlanta, GA',292,1988,188356,55000000,NULL,'2025-09-25','2026-02-24','All Docs Saved

under contract / retrade, 52-53 is the number

 - Not sure if I responded, had email issues in the past week. Target here is mid $190k’s/unit.  Offering good leveraged financing to help.  ',TRUE,TRUE,'Newmark'),
('Boatman Hammock Townhomes','2 - Active','West Palm Beach-Boca Raton, FL',54,2024,370370,20000000,'2026-03-12','2026-02-03','2026-02-17','All Docs Saved - Ethan – Thanks for reaching out, hope all is well on your side.   

We’re targeting lower $20 millions range (upper $300Ks / low $400Ks per unit ballpark) on pricing.  A few of the key summary points noted below... 

Boatman Hammock (West Palm Beach):
•	54-unit, amenitized build-to-rent (BTR) townhome community completed in 2024 by a national public homebuilder 
•	Seller is a private JV between Acasa Living / Bain Capital who acquired units at completion, and leased-up the commu',TRUE,TRUE,'Berkadia'),
('Lymestone Ranch','5 - Dormant','DaytonaBeach, FL',216,2004,166667,36000000,NULL,'2025-11-13','2026-01-23','All Docs Saved - Ethan, 
Our guidance for Lymestone Ranch is $36,000,000 ($166,667 PU or $171 PSF) which is a 6.10% in-place cap rate, adjusting for normalized vacancy and insurance. You can get to a stabilized 7.6% cap after completing renovations. 
Lymestone Ranch is a 216-unit garden-style community built in 2004, located in New Smyrna Beach - voted one of the "50 Best Beach Towns in the South.” The Property benefits from immediate I-95 access, with direct access to AdventHealth New Smyrna Be',TRUE,TRUE,NULL),
('Elevate at Tryon','5 - Dormant','Charlotte-Gastonia-Rock Hill, NC-SC',86,1927,162791,14000000,NULL,'2025-10-20','2026-01-23','All Docs Saved - Ethan - hope you''re doing well.  Thanks for reaching out.

Our pricing guidance is $14M.  

The deal was under construction for the balance of the past 2+ years. The elevator took about 12 months to get replaced and the property did not have an elevator. The play here is to mark the rents to market, our proforma takes the highest in-place rents per unit type and marks the lower rents to that number. This actually provides a significant bump in rents. 

The property is actually t',TRUE,TRUE,NULL),
('Chartwell Commons at Beechcroft','5 - Dormant','',124,2023,443548,55000000,NULL,'2025-09-25','2026-01-23','All Docs Saved - Ethan,
Thanks for reaching out on Beechcroft.  Below is a summary of the opportunity.  
 
We’re expecting pricing in the $450Ks per home (e.g. $55.8mm) which equates to ~a 5.25% Yr1 stabilized cap rate.  CFO has not been set but we’re anticipating a mid-October date.
Beechcroft is the only detached BTR in the southwest quadrant of the Nashville MSA, the area’s most affluent.  At over, 2,000sf home size, median divided entry, and sidewalks throughout the community, no property fe',TRUE,TRUE,NULL),
('The Columns At Wakefield','10 - Owned Property','Raleigh-Durham-Chapel Hill, NC',324,2002,192901,62500000,NULL,'2020-07-24','2026-01-15','7/24

Going to be listed soon by CBRE - Howard Jenkins will give us early look (hopefully)

Pricing needs to be close to or over 60 mil, Seller (Passco) has substantial prepay they need to eat if they are going to sell',TRUE,FALSE,NULL),
('The Gramercy at Town Center','10 - Owned Property','Baltimore, MD',210,1998,319048,67000000,'2021-04-16','2021-03-22','2026-01-14','4.4% cap in place (tax adj)

PGIM is seller

opportunity to jump in early',TRUE,FALSE,NULL),
('Luxe at 1820','10 - Owned Property','Tampa-St. Petersburg-Clearwater, FL',300,2009,260000,78000000,'2025-08-27','2025-07-23','2026-01-13','All Docs Saved - $270k/unit
',TRUE,FALSE,NULL),
('Haven at Patterson Place Apartments','10 - Owned Property','Raleigh-Durham-Chapel Hill, NC',242,2002,232231,56200000,'2021-10-27','2021-10-04','2026-01-06','docs saved. OM saved.
"Please note,
-	Low $50Ms starting guidance
-	At $51.0M as a reference point ($211K PU / $198/SF), equivalent to an in-place 3.91%, tax-adjusted 3.59% cap
o	In-place definition: T1 EGR ($1,231 NER, 93.9% Econ Occ), T12 Other Income/Insurance, T12 Controllables, 2.75% Mgt Fee, FY1 RET, $275 Reserve
o	Tax-adjusted: pull forward FY5 (2026) estimated tax increment (assumed 95% of price, 5% mil rollback, 2% per annum tax growth otherwise)   
-	We will officially launch tomorrow,',TRUE,TRUE,NULL),
('The Banks at Mt. Holly Apartments','5 - Dormant','Charlotte-Gastonia-Rock Hill, NC-SC',314,2023,273885,86000000,NULL,'2025-09-10','2025-12-10','All Docs Saved - $275k/door',TRUE,TRUE,NULL),
('The Villas At Trevi Village','5 - Dormant','Charlotte-Gastonia-Rock Hill, NC-SC',204,2024,269608,55000000,NULL,'2025-11-05','2025-12-03','No Docs Off Market

220+/- units
•	Built 2024
•	Interior corridor product
•	Class A amenities
•	12'' ceilings in many units
•	Delivered offmarket 
•	Pricing: $272k+/- per unit, which is below the developer''s cost. 
',FALSE,FALSE,NULL),
('The Conwell','10 - Owned Property','Washington, DC-MD-VA',72,1959,311111,22400000,NULL,'2022-02-15','2025-12-02','',TRUE,FALSE,NULL),
('Connecticut Plaza Apartments','10 - Owned Property','Washington, DC-MD-VA',236,1927,279661,66000000,NULL,'2022-04-27','2025-12-02','all docs saved
started as financing attempt, due to changed situation for one of partners, now open to selling
offer date in next few weeks (likely week of 5/9)
70M strike ~300/unit range, if you are not there still could be relavent
interior value add business plan',TRUE,FALSE,NULL),
('The Leo Loso','5 - Dormant','Charlotte-Gastonia-Rock Hill, NC-SC',284,2023,NULL,'',NULL,'2025-10-24','2025-10-24','Please see attached Updated RR and below info re Leo LoSo

https://theleoloso.com/

The property is +/- 75% occupied; however, it is not on the market.
We''d entertain offers at north of $325K p/u.
We have a +/- $55MM HUD loan at 2.89% with a 38 year remaining term that needs to be assumed. We won''t provide a T12 for now. Only RR. 
',TRUE,FALSE,NULL),
('Prose Steven''s Pointe','5 - Dormant','Orlando, FL',264,2022,NULL,'',NULL,'2025-10-02','2025-10-14','No Docs Alliance/ZRS',FALSE,FALSE,NULL),
('Provenza at Park Place','5 - Dormant','Nashville, TN',290,2022,NULL,'',NULL,'2025-10-02','2025-10-14','No Docs Momentum/ZRS',FALSE,FALSE,NULL),
('Broadstone Overlands','5 - Dormant','Orlando, FL',200,2024,NULL,'',NULL,'2025-10-02','2025-10-14','No Docs Alliance/ZRS',FALSE,FALSE,NULL),
('Thrive University City','10 - Owned Property','Charlotte-Gastonia-Rock Hill, NC-SC',309,2020,210680,65100000,NULL,'2024-12-16','2025-10-01','All Docs Saved - Off Mkt from Northmarq

$215k per unit

Hey guys, I was moving fast the other day when I started thinking about this University deal we have.   My comment about you “dollar cost averaging your basis” was because I was thinking about Where we SOLD Magnolia for you…  The reason I thought of this other deal for you is its exactly like the conversation we had on Magnolia when you bought it (great great basis coming out of covid)…  so wondered if you wanted to do a repeat kind of dea',TRUE,TRUE,NULL),
('NOVEL Beach Park','5 - Dormant','Tampa-St. Petersburg-Clearwater, FL',289,2024,NULL,'',NULL,'2025-07-23','2025-09-17','Coming Soon - For Tracking Purposes',FALSE,FALSE,NULL),
('Village at Lake Highland Apartments','7 - Lost','Lakeland-Winter Haven, FL',320,2001,210938,67500000,'2025-08-21','2025-07-23','2025-09-15','All Docs Saved - Thank you for your interest in Village at Lake Highland - an exceptional opportunity to invest in a well-maintained, value-add multifamily community located in Lakeland, within Polk County, Florida’s fastest-growing county. The whisper price is $67.5M, reflecting a 5.75 cap on the T3 income with T12 expenses adjusted for insurance and taxes.
 
Built in 2001, this 320-unit apartment community is strategically positioned just minutes from major employers such as the upcoming Orlan',TRUE,TRUE,NULL),
('Independence Park Apartments in Durham, NC','5 - Dormant','Raleigh-Durham-Chapel Hill, NC',312,2008,217949,68000000,NULL,'2025-07-29','2025-09-03','All Docs Saved - Will work on an overview of the opportunity, but wanted to get you what we have thus far so you can get going.

Ownership''s renovation includes sprayed faux granite countertops, stainless steel appliances, white cabinetry, lighting / plumbing fixtures, and vinyl flooring. 

Avana on Broad is the best comp (2000 build, 8ft product), they''re doing quartz, stainless steel appliances, backsplash, white cabinetry, new lighting / plumbing fixtures, and vinyl flooring throughout. They''',TRUE,TRUE,NULL),
('Cameron South Park','5 - Dormant','Charlotte-Gastonia-Rock Hill, NC-SC',309,1984,239482,74000000,NULL,'2025-07-29','2025-09-03','All Docs Saved - StoneBridge Team – Please keep confidential. $74M ($240k/unit) is the bogey. Unclear how much room they have off that. Given the very quiet nature of this one, I have not pulled together an overview of the opportunity. The asset does sit in one of the wealthiest, high barrier to entry pockets of Charlotte on 35 acres.

Reminder this one is already in the abatement program. The owner restricts 100% of the property to 80% AMI levels in exchange for a full property tax abatement.
',TRUE,TRUE,NULL),
('Fifth Street Place Apartments','7 - Lost','Charlottesville, VA',200,2018,270000,54000000,'2025-08-13','2025-07-11','2025-08-28','All Docs Saved -
Highlights:
•	2018 Vintage
•	200 Units (23 affordable units roll to market in Aug 2028 adding ~$1.8M of value)
•	99.5% leased while aggressively pushing rents
o	+11.7% on last 30 trade-outs
o	+6.0% on last 30 renewals
•	$1,902 avg rents (excludes affordable units)
o	24% rental discount vs comps
o	20% on-site demographic rent to income ratio
•	Ability to acquire below replacement cost
•	Insulated from new supply with zero market rate units under construction within 3-mile radius
',TRUE,TRUE,NULL),
('Eagle Rock Apartments at Columbia','5 - Dormant','Baltimore, MD',184,1984,NULL,'',NULL,'2025-07-30','2025-08-27','No Docs',FALSE,FALSE,NULL),
('Stono Oaks','5 - Dormant','Charleston-North Charleston, SC',240,2024,NULL,'',NULL,'2025-08-14','2025-08-21','Coming Soon - $65M ish',FALSE,FALSE,NULL),
('MAA Stonefield','5 - Dormant','Charlottesville, VA',250,2013,NULL,'',NULL,'2025-08-14','2025-08-21','',FALSE,FALSE,NULL),
('Madison Gateway','7 - Lost','Tampa-St. Petersburg-Clearwater, FL',314,1999,299363,94000000,'2025-07-31','2025-06-24','2025-08-08','Offered $92.5MM First Round 8/1/25

All Docs Saved - Ethan – thanks for reaching out. 

Guidance is $300-305k per unit. 5.25% in-place.

There’s headroom to take these units up to a more premium finish given product differentiation, barriers, operating trends, and resident demos. 

Let us know if you’d like to discuss.
',TRUE,TRUE,NULL),
('The Rothbury Apartments','5 - Dormant','Washington, DC-MD-VA',205,2005,275610,56500000,NULL,'2024-07-15','2025-06-19','All Docs saved - Asking Price: $­­56.5MM (I would encourage a bid at the price point that you like it)

Could be coming back on the market soon, Northmarq BOV/pitched to Klingbeil 6/18/25',TRUE,TRUE,NULL),
('The Newton Apartments','7 - Lost','Charlotte-Gastonia-Rock Hill, NC-SC',274,2020,262774,72000000,'2025-05-22','2025-04-24','2025-06-18','All Docs Saved -
Guidance is $72M/low 260s, high 4 in place, getting to a 5.5 Y1 by completing flooring & adding bulk Wifi.
 
We would encourage you to jump on the underwriting quickly as this will only be out for a few weeks. We will conduct tours for those that can get within 2-3% of guidance.
',TRUE,TRUE,NULL),
('Treeline Timber Creek Apartments','5 - Dormant','Raleigh-Durham-Chapel Hill, NC',304,2018,NULL,'',NULL,'2025-05-07','2025-06-12','Off Market John Phoenix',FALSE,FALSE,NULL),
('Enders Place at Baldwin Park Apartments','7 - Lost','Orlando, FL',220,2003,318182,70000000,'2025-04-30','2025-03-28','2025-05-29','Offered $71MM 5/1/25

All Docs Saved  ZRS Managed - Around $70MM',TRUE,TRUE,NULL),
('Provenza at Indian Trail','7 - Lost','Charlotte-Gastonia-Rock Hill, NC-SC',204,2017,240196,49000000,'2025-05-13','2025-03-27','2025-05-27','Awarded at $49.5MM
Offered $46MM 5/14/25
Offered $48MM 5/20/25
All Docs Saved - Hey Ethan, guiding $240k per unit here, we see that as a 5 in place. Let me know if I can answer any questions after you dig in. Great asset ZRS Managed',TRUE,TRUE,NULL),
('Cortland Vera Sanford','7 - Lost','Orlando, FL',332,2018,271084,90000000,'2025-04-15','2025-03-12','2025-05-13','Offered $87MM 4/16/25

All Docs Saved - Jay – apologies on the delay.

Guidance is $270-275k per unit. Deal room access was just granted, and you should see another RCM blast later this afternoon.

Key deal points below – 
•	Differentiated product – three-story elevator-served w/ 17% townhomes w/ direct-access garages 
•	Affluent area demographics – both incomes & home prices
•	Desirable submarket employment concentrations 
•	Tail end of pipeline – the submarket has worked through 1,000 units of',TRUE,TRUE,NULL),
('Huxley Scottsdale','7 - Lost','Phoenix-Mesa, AZ',192,2024,406250,78000000,'2025-04-22','2025-02-04','2025-05-09','All Docs Saved - $78MM',TRUE,FALSE,NULL),
('Cathedral Commons','5 - Dormant','Washington, DC-MD-VA',145,2015,413793,60000000,'2025-03-11','2025-02-04','2025-04-16','All Docs Saved - Guidance is $140M-$150M range.

 Offered $58MM 3/12/25

Multifamily - ~$60MM ($410K/Unit) – mid-5% cap rate

Retail - $85MM - $90MM (~720 PSF) - ~6.00% cap rate',TRUE,FALSE,NULL),
('Marq Eight','7 - Lost','Atlanta, GA',312,2009,256410,80000000,'2025-03-25','2025-01-22','2025-04-16','All Docs Saved
Offered $72.5 3/25/25

update 3/18- Will talked to Derrick and holding strong at 80M, we should offer what we can

Acq meeting: we are low 70s

Notes from Call with David Gutting
•	Marq Eight – 2009 312 Units
•	Deal is on SE Corner of Perimeter
o	This area has seen more of a live-work-play transformation in recent years
•	Built by Lane Company who sold to PGIM in 2012, originally built as a condo conversion
o	CWS then bought from PGIM in 2017 with plans to renovate but ended up do',TRUE,TRUE,NULL),
('Sole at Casselberry','7 - Lost','Orlando, FL',336,2017,254464,85500000,'2025-03-26','2025-02-20','2025-04-16','Offered $78MM 3/26/25

3/18: offer to stay relevant ~mid high 70Ms

All Docs Saved - o	Guiding to $255k/door = $85.5MM
o	5.1 Cap on in place
o	Nuveen is seller, fund is at end of life cycle and loan matures at end of year
o	Lot of early interest, lot of groups like this type of product
',TRUE,FALSE,NULL),
('The Tribute','7 - Lost','Raleigh-Durham-Chapel Hill, NC',359,2010,222841,80000000,'2025-04-02','2025-03-11','2025-04-07','Offered $74MM First CFO

All Docs Saved - Hey, Ethan. Thank you for reaching out on Tribute in Raleigh.
 
Initial pricing guidance is in the low $80Ms, which is in the $220s/u and reflects a ~30% discount to replacement cost for structure-parked product. Tribute represents a desirable core-plus profile and the projected post-renovation basis is less than recent new construction sales in the Triangle. 
 
We are likely to call for offers at the beginning of April. Let us know what questions you ha',TRUE,TRUE,NULL),
('Poplar Glen','7 - Lost','Baltimore, MD',192,1986,239583,46000000,'2025-03-12','2025-02-03','2025-03-27',' All Docs Saved - Pricing is around $46M.
Initial Offer: $44MM 3/13/25
B&F Offer: $45MM

Let us know what else you need as you begin your underwriting.
',TRUE,FALSE,NULL),
('Mariner Bay at Annapolis Town Center','7 - Lost','Baltimore, MD',208,2009,450000,93600000,'2024-11-12','2024-09-11','2024-12-12','All Docs Saved - Pricing guidance on Mariner Bay is around $93.6mm / $450kpu, which is 5.6% on T12

Offered $84MM 11/13/24',TRUE,TRUE,NULL),
('Crosswinds at Annapolis Town Center','7 - Lost','Baltimore, MD',215,2013,330233,71000000,'2024-11-12','2024-09-11','2024-12-12','All Docs Saved - Pricing guidance here is around $70.95mm / $330kpu, which is 5.5% on T12

Offered $68MM 11/13/24',TRUE,TRUE,NULL),
('Rockford','10 - Owned Property','Washington, DC-MD-VA',68,'',NULL,'',NULL,'2018-04-12','2024-11-19','',TRUE,FALSE,NULL),
('Essence on Maple','7 - Lost','Dallas-Fort Worth, TX',340,2019,255000,86700000,'2024-07-23','2024-07-08','2024-10-07','All Docs saved - We anticipate that Essence on Maple will land in the mid $250ks per unit. The property has excellent rent trends, is currently over 96% occupied, and the cap rate projects as a mid-5% cap forward. A link to more information is below.


Link to the Essence on Maple Information: Essence on Maple Information

Essence on Maple Luxury Apartments Highlights:
•	A 340-unit luxury residential midrise developed by Trammell Crow Residential in 2019.
•	Across the street from Old Parkland’s ',TRUE,TRUE,NULL),
('Henley Tampa Palms Apartments','7 - Lost','Tampa-St. Petersburg-Clearwater, FL',315,1997,253968,80000000,'2024-08-20','2024-07-17','2024-09-17','All Docs Saved - Thank you for reaching out.  We are expecting pricing to be in the $80mm - $83mm range ($185/sf - $192/sf or $255k/unit - $265k/unit).   At this price point, the basis is significantly below replacement, which is estimated to be in excess of $350,000 per unit given the very large units, direct entries, attached garages, etc.   The cap rate works out to 5.0% - 5.25% on in-place and builds to a 6.5% YOC after completing a VA strategy.    

As noted in the teaser, Henley Tampa Palm',TRUE,TRUE,NULL),
('Avana Bayview Apartments','7 - Lost','Fort Lauderdale-Hollywood, FL',225,2004,330000,74250000,'2024-08-21','2024-07-11','2024-09-11',' All Docs saved - Target pricing is $330,000 per unit, ~5 cap.  Great info location, plenty of upside on the interiors.  Would you like to arrange a time to discuss or a tour at the property? 

 ',TRUE,TRUE,NULL),
('The Ivy Residences at Health Village','7 - Lost','Orlando, FL',248,2015,260000,64480000,'2024-08-01','2024-07-02','2024-08-14',' All docs saved - We’re targeting pricing in the $260Ks per unit range, which is ±5.25% cap rate territory on in-place figures. OM & marketing materials will be out next week. Let us know any questions in the interim.

 

We’re also bringing out Bainbridge Nona North next week.',TRUE,TRUE,NULL)
ON CONFLICT (name) DO NOTHING;

INSERT INTO deals (name,status,market,units,year_built,price_per_unit,purchase_price,bid_due_date,added,modified,comments,flagged,hot,broker) VALUES
('The Venue Craig Ranch','7 - Lost','Dallas-Fort Worth, TX',277,2016,232852,64500000,NULL,'2024-07-01','2024-08-14','all docs saved - low to mid 230k per unit',TRUE,FALSE,NULL),
('Aspire Perimeter','7 - Lost','Atlanta, GA',296,1996,229730,68000000,'2024-07-25','2024-07-01','2024-07-29','all docs saved
offers due ~7/25
Jay – Glad you’re digging in here. Guidance is $225K-$235K/unit, which is a 5.50% tax adjusted, in-place cap rate, a 5.75% occupancy adjusted cap rate, with the ability to be north of 6.50% through addition of other income streams and light interior value-add. 
The property has a $48M in-place assumable loan at a 3.50% interest rate with 5.5 years left on the term!
Let us know if you’d like to hop on a call or setup a tour.  We will likely launch the Offering Memo',TRUE,TRUE,NULL),
('The Point at Ridgeline','5 - Dormant','Washington, DC-MD-VA',294,2019,NULL,'',NULL,'2024-05-09','2024-07-18','no docs - coming soon / off mkt from Berkadia (we can get first look)

Berkadia’s BOV is 150 mil combined, not sure how it allocates per deal. id guess ridgeline is going to have higher rents and be more expensive given the construction quality

Nice quality deals, and per Crivella they are blank slate value-add opportunities
',FALSE,FALSE,NULL),
('The Manor In Plantation','7 - Lost','Fort Lauderdale-Hollywood, FL',197,2013,289340,57000000,'2024-02-27','2024-01-25','2024-06-24','?	Total (~57 mil), 290k / dr
?	Basis attractive – new builds replacement cost ~ $400-425k / unit
?	In place 5.25 (tax + ins adj) per broker
',TRUE,TRUE,NULL),
('Dartmoor Place','7 - Lost','Baltimore, MD',258,2019,348837,90000000,'2023-02-16','2023-03-14','2024-03-27','$90M, offer came in for $92M but uncertain of ability to close, could go below $90M',TRUE,TRUE,NULL),
('Provenza at Windhaven','7 - Lost','Dallas-Fort Worth, TX',324,2015,231481,75000000,'2024-02-06','2024-01-24','2024-02-26','75M, 230/unit, 5.25cap ',TRUE,TRUE,NULL),
('The Everly at Historic Franklin','7 - Lost','Nashville, TN',218,2013,309633,67500000,'2024-01-16','2024-01-04','2024-02-06','all docs saved

Tough to give guidance right now. Have been closing stuff the last few weeks sub 5%, while most buyers are looking for something much higher than that. This is a special deal, so I expect good interest. With all that said, upper $60mm’s.  ',TRUE,TRUE,NULL),
('Springfield','7 - Lost','Raleigh-Durham-Chapel Hill, NC',288,1986,NULL,'',NULL,'2019-02-25','2023-12-20','',TRUE,FALSE,NULL),
('St. Johns Wood','7 - Lost','Washington, DC-MD-VA',250,1990,314000,78500000,'2023-10-17','2023-10-03','2023-10-19','all docs saved
Pricing 78.5M = 5.25% cap t3/t12, CFO mid/late Oct – Per Zach Stone
JS: good location and demos, 2 miles north of RTC, should probably tour
',FALSE,FALSE,NULL),
('Beech’s farm ','9 - Exited','Baltimore, MD',135,'',NULL,'',NULL,'2018-03-21','2023-09-07','',TRUE,TRUE,NULL),
('River Vista','9 - Exited','Atlanta, GA',196,1996,170000,33320000,'2019-03-12','2019-02-27','2023-09-07','',TRUE,FALSE,NULL),
('SPG for Delete','9 - Exited','Raleigh-Durham-Chapel Hill, NC',346,1988,NULL,'',NULL,'2019-04-11','2023-09-07','',TRUE,FALSE,NULL),
('Sutton Place','9 - Exited','Raleigh-Durham-Chapel Hill, NC',83,1993,NULL,'',NULL,'2019-03-14','2023-09-07','',TRUE,TRUE,NULL),
('Seven Oaks','9 - Exited','Baltimore, MD',278,1990,NULL,'',NULL,'2018-06-14','2023-09-07','',TRUE,FALSE,NULL),
('Copper Springs','9 - Exited','Richmond-Petersburg, VA',366,'',NULL,'',NULL,'2018-02-12','2023-09-07','',TRUE,TRUE,NULL),
('Berkshire 15 Apartments','7 - Lost','Washington, DC-MD-VA',96,2016,375000,36000000,'2023-08-22','2023-07-24','2023-09-06','all docs saved
Guiding to $36M -- $375k/unit.
5.5% Cap in place.',TRUE,TRUE,NULL),
('Oakbrook Townhomes','7 - Lost','Nashville, TN',89,2023,505618,45000000,'2023-08-23','2023-07-31','2023-08-29','all docs saved

We are guiding in the mid 40mm’s on this one, which equates to low $500’s per unit or ~$275 PSF range. Given unit sizes (1,879 avg), the per unit metric is a little misleading, as the units are 2x the normal multi deal. The last conventional, new construction multi sale in Cool Springs (The Harper), traded for $450 PSF for comparison and the last townhome / BTR trade that is very similar to this (780 Townhomes) sold in the mid $700’s pu / $400 psf. 
 
The demo’s on this one are v',TRUE,TRUE,NULL),
('Riverside Station Apartments','7 - Lost','Washington, DC-MD-VA',304,2005,263158,80000000,'2023-06-22','2023-05-16','2023-07-24','all docs saved
was 85-90M
Pricing is around $80M. We had this on the market last year, but paused the process due to the movement in interest rates.

',FALSE,TRUE,NULL),
('Avia East Cobb (prior to Acq)','9 - Exited','Atlanta, GA',200,1978,NULL,'',NULL,'2018-03-02','2023-02-21','',TRUE,TRUE,NULL),
('Veridian at Sandy Springs','9 - Exited','Atlanta, GA',272,'',NULL,'',NULL,'2018-02-12','2023-02-21','',TRUE,TRUE,NULL),
('Peabody','9 - Exited','Washington, DC-MD-VA',14,'',NULL,'',NULL,'2018-03-29','2023-02-21','',TRUE,TRUE,NULL),
('Landry East Cobb','9 - Exited','Atlanta, GA',200,1978,NULL,'',NULL,'2018-09-21','2023-02-21','',TRUE,FALSE,NULL),
('Magnolia Terrace','9 - Exited','Charlotte-Gastonia-Rock Hill, NC-SC',264,1989,154242,40720000,NULL,'2020-02-25','2023-02-21','',TRUE,TRUE,NULL),
('Southpoint Glen + Trails','9 - Exited','Raleigh-Durham-Chapel Hill, NC',429,1988,NULL,'',NULL,'2018-07-18','2023-02-21','',TRUE,TRUE,NULL),
('Marietta Crossing Apartment Homes','11 - Property Comp','Atlanta, GA',420,1975,238095,100000000,'2022-02-09','2022-01-07','2022-01-27','all docs saved.
-"Guidance for the portfolio is $170M, Marietta Crossing ($100M or $238k/unit) and Alder Park ($70M or $260k/unit)"
-"Both assets recently completed amenity refreshes (tennis court conversions), that turned out exceptional"
-"In addition, both assets have been renovating units over the last three years to bring units to one scope and scale"
-"Marietta Crossing has ~41% of units remaining to be renovated, netting $250-$300 premiums post-renovation"
-"Property level performance at ',TRUE,FALSE,''),
('Discovery Gateway Apartments','11 - Property Comp','Atlanta, GA',388,1986,NULL,'',NULL,'2022-01-07','2022-01-11','coming soon',FALSE,FALSE,''),
('Berkshire Howell Mill','7 - Lost','Atlanta, GA',256,2015,242188,62000000,'2021-09-07','2021-08-11','2021-10-18','all docs saved',TRUE,TRUE,NULL),
('Marquis at Cinco Ranch','7 - Lost','Houston, TX',260,20112015,215385,56000000,'2021-09-14','2021-08-05','2021-10-18','all docs saved
Pricing around 56M (from call with Dustin and Elliott)',TRUE,TRUE,NULL),
('Hazel SouthPark® Apartments','11 - Property Comp','Charlotte-Gastonia-Rock Hill, NC-SC',203,2021,NULL,'',NULL,'2021-09-17','2021-09-28','',TRUE,FALSE,''),
('Hidden Creek Apartment Homes','11 - Property Comp','Dallas-Fort Worth, TX',362,1999,NULL,'',NULL,'2020-10-02','2021-04-20','',TRUE,FALSE,''),
('The Reserve at Wescott Plantation','7 - Lost','Charleston-North Charleston, SC',288,'',152778,44000000,'2021-03-04','2020-01-29','2021-03-11','B&F offer of 45.2 MM, probably about $1 MM short of final pricing...',TRUE,TRUE,NULL),
('The Gateway','11 - Property Comp','Dallas-Fort Worth, TX',254,2013,NULL,'','2021-02-04','2020-09-23','2021-01-22','',TRUE,FALSE,''),
('The Flats at Shadowglen','7 - Lost','Austin-San Marcos, TX',248,2019,181452,45000000,'2020-12-10','2020-11-11','2020-12-16','',TRUE,FALSE,NULL),
('Toscana at Sonterra Apartments','7 - Lost','San Antonio, TX',248,1998,127016,31500000,'2020-12-10','2020-11-10','2020-12-16','',TRUE,TRUE,NULL),
('Centreport Lake Luxury Apartments','7 - Lost','Fort Worth, TX',452,2008,199115,90000000,'2020-10-01','2020-09-14','2020-12-16','',TRUE,TRUE,NULL),
('Sixty25 at Ridglea Hills Apartments','7 - Lost','Fort Worth, TX',244,2005,139344,34000000,'2020-10-22','2020-09-21','2020-12-16','10/20 update:  discussed with LEM.  They know the deal and are willing to get aggressive with non-agency debt fund options.  Have some relationships trying to close out year with floating rate well below typical bridge debt interest rates.  

',TRUE,TRUE,NULL),
('Villas of Vista Ridge','7 - Lost','Dallas-Fort Worth, TX',323,2002,198142,64000000,'2020-10-13','2020-09-23','2020-12-16','send to jv equity
',TRUE,TRUE,NULL),
('The Station at MacArthur Apartments','11 - Property Comp','Dallas-Fort Worth, TX',444,1994,NULL,'',NULL,'2020-10-01','2020-11-10','CAF & Cantor Fitzgerald partnership

- they dropped it during covid and walked from $2mm deposit
- came back and paid $3mm higher on price w/o credit for the $2mm lost',TRUE,FALSE,''),
('Hebron 121 Station Phase 5','11 - Property Comp','Dallas-Fort Worth, TX',273,2019,NULL,'',NULL,'2020-10-14','2020-10-14','',TRUE,FALSE,''),
('Hebron 121 Station Phase 4','11 - Property Comp','Dallas-Fort Worth, TX',236,2016,NULL,'',NULL,'2020-10-14','2020-10-14','',TRUE,FALSE,''),
('Hebron 121 Station Phase 3','11 - Property Comp','Dallas-Fort Worth, TX',242,2015,NULL,'',NULL,'2020-10-14','2020-10-14','',TRUE,FALSE,''),
('Hebron 121 Station Phase 2','11 - Property Comp','Dallas-Fort Worth, TX',444,2013,NULL,'',NULL,'2020-10-14','2020-10-14','',TRUE,FALSE,''),
('Hebron 121 Station Phase 1','11 - Property Comp','Dallas-Fort Worth, TX',234,2010,NULL,'',NULL,'2020-10-14','2020-10-14','',TRUE,FALSE,''),
('Coventry at Cityview Apartment Homes','11 - Property Comp','Fort Worth, TX',360,1996,NULL,'',NULL,'2020-10-12','2020-10-12','',TRUE,TRUE,''),
('The Heights of Cityview','11 - Property Comp','Fort Worth, TX',344,1999,NULL,'',NULL,'2020-10-12','2020-10-12','',TRUE,TRUE,''),
('Alta Waterside','11 - Property Comp','Fort Worth, TX',361,2019,NULL,'',NULL,'2020-10-12','2020-10-12','',TRUE,FALSE,'Newmark'),
('Ridglea Village','11 - Property Comp','Fort Worth, TX',253,2003,NULL,'',NULL,'2020-10-12','2020-10-12','',TRUE,FALSE,'Newmark'),
('Breckinridge Point Apartment Homes','7 - Lost','Dallas-Fort Worth, TX',440,1998,202273,89000000,'2020-10-01','2020-09-08','2020-10-08','17 offers total, 7 groups in B&F round with $90mm cutoff.  Few groups in the $92-93mm range.  We offered $88mm.
',TRUE,FALSE,NULL),
('Grapevine TwentyFour 99','11 - Property Comp','Fort Worth, TX',348,2003,NULL,'',NULL,'2020-10-02','2020-10-02','',TRUE,TRUE,''),
('Arioso Apartments & Townhomes','11 - Property Comp','Dallas-Fort Worth, TX',288,2007,NULL,'',NULL,'2020-10-02','2020-10-02','',TRUE,TRUE,'C&W'),
('Eleven11 Lexington at Flower Mound','11 - Property Comp','Dallas-Fort Worth, TX',222,1998,NULL,'',NULL,'2020-10-02','2020-10-02','',TRUE,FALSE,''),
('2803 Riverside Apartment Homes','11 - Property Comp','Dallas-Fort Worth, TX',436,1999,NULL,'',NULL,'2020-10-02','2020-10-02','',TRUE,TRUE,''),
('St. Marin Apartments','11 - Property Comp','Dallas-Fort Worth, TX',603,2001,NULL,'',NULL,'2020-10-01','2020-10-01','',FALSE,FALSE,''),
('Wind Dance Apartments','11 - Property Comp','Dallas-Fort Worth, TX',298,2003,NULL,'',NULL,'2020-10-01','2020-10-01','',TRUE,TRUE,''),
('The Anthem Apartments','11 - Property Comp','Dallas-Fort Worth, TX',231,1996,NULL,'',NULL,'2020-10-01','2020-10-01','',TRUE,TRUE,'Rosewood'),
('Watervue','11 - Property Comp','Fort Worth, TX',399,2009,NULL,'',NULL,'2020-09-23','2020-09-24','',TRUE,FALSE,''),
('Gateway Crossing','11 - Property Comp','Dallas-Fort Worth, TX',322,2015,NULL,'',NULL,'2020-09-23','2020-09-23','',TRUE,FALSE,'Northmarq'),
('The Hendry Apartment Homes','11 - Property Comp','Dallas-Fort Worth, TX',399,2017,NULL,'',NULL,'2020-09-23','2020-09-23','',TRUE,FALSE,''),
('Galatyn Station','11 - Property Comp','Dallas-Fort Worth, TX',285,2008,NULL,'',NULL,'2020-09-23','2020-09-23','',TRUE,FALSE,'JBM'),
('The Lofts at Palisades Apartments','11 - Property Comp','Dallas-Fort Worth, TX',343,2018,NULL,'',NULL,'2020-09-23','2020-09-23','',TRUE,FALSE,''),
('The Flats at Palisades Apartments','11 - Property Comp','Dallas-Fort Worth, TX',232,2018,NULL,'',NULL,'2020-09-23','2020-09-23','',TRUE,FALSE,''),
('Alexan Crossings Apartments','11 - Property Comp','Dallas-Fort Worth, TX',354,2018,NULL,'',NULL,'2020-09-23','2020-09-23','',TRUE,FALSE,'Northmarq'),
('Axis 110','11 - Property Comp','Dallas-Fort Worth, TX',351,2017,NULL,'',NULL,'2020-09-23','2020-09-23','',TRUE,FALSE,''),
('The Point at Laurel Lakes','7 - Lost','Washington, DC-MD-VA',308,1987,211039,65000000,'2020-07-22','2020-06-18','2020-08-25','whisper was 64-65. offered 63.75 mm on 7/24',TRUE,TRUE,NULL),
('The Preserve at Catons Crossing Apartments','7 - Lost','Washington, DC-MD-VA',200,2010,275000,55000000,'2020-07-30','2020-06-25','2020-08-25','7/20

Bid made of $54.8 MM. also reached out to Gino at Fairfield 

Spoke w Angela at ZRS, they are scrubbing expenses on T12 and will get back to us w feedback',TRUE,TRUE,NULL),
('Quail Valley on Carmel','7 - Lost','Charlotte-Gastonia-Rock Hill, NC-SC',232,1978,163793,38000000,'2020-07-30','2020-07-16','2020-08-25','7/31

Bid made for $36.350 MM, expect B&F due 8/7; offers likely > 37 m

Darryl Hemminger to give redevelopment feedback (apt / TH mixed use) by Wed Aug 5 to be used in B&F bid',TRUE,TRUE,NULL),
('550 Abernathy','9 - Exited','Atlanta, GA',228,'',NULL,'',NULL,'2018-02-16','2020-08-25','',TRUE,TRUE,NULL),
('The Point at Hampton Hollow','7 - Lost','Washington, DC-MD-VA',240,1987,197917,47500000,'2020-07-15','2020-06-18','2020-07-28','7/20:

Offered $45.5 MM


Per Dean Sigmon:
 
The asset has strong in-place cash flow with a T-12 NOI of about $2.55 million. T-3 over T-12 north of $2.6 million.
 
Should do well as a value add deal as interiors really have not been touched since mid-2000’s.
 
Low 5 cap to 5.25% on in-place something closer to mid 5’s on year one. High $40’s million $200k + or -
 
Asset has witnessed minimal impact from COVID-19.',TRUE,TRUE,NULL),
('Glenwood','9 - Exited','Washington, DC-MD-VA',90,'',NULL,'',NULL,'2018-02-16','2020-06-05','',TRUE,FALSE,NULL),
('Trailside at Reedy Point','7 - Lost','Greenville-Spartanburg-Anderson, SC',215,2017,NULL,'',NULL,'2019-08-01','2020-06-05','',TRUE,FALSE,NULL),
('Halstead Dulles','7 - Lost','Washington, DC-MD-VA',244,2004,NULL,'',NULL,'2018-06-06','2020-06-05','',TRUE,FALSE,NULL),
('The Lodge at Copperfield','7 - Lost','Houston, TX',330,1998,NULL,'',NULL,'2018-07-24','2020-06-05','',TRUE,FALSE,NULL),
('Hawthorne at Lake Norman','7 - Lost','',232,'',NULL,'',NULL,'2020-01-27','2020-06-05','',TRUE,TRUE,NULL),
('Hawthorne at the Trace','7 - Lost','Raleigh-Durham-Chapel Hill, NC',250,'',NULL,'',NULL,'2020-01-28','2020-06-05','',TRUE,TRUE,NULL),
('Parc at University Tower Apartments','7 - Lost','Raleigh-Durham-Chapel Hill, NC',186,'',NULL,'',NULL,'2020-01-21','2020-06-05','',TRUE,TRUE,NULL),
('Southpoint Crossing Apartments','7 - Lost','Raleigh-Durham-Chapel Hill, NC',288,'',NULL,'',NULL,'2020-01-15','2020-06-05','',TRUE,TRUE,NULL),
('Hickory Creek','7 - Lost','Richmond-Petersburg, VA',294,1984,150000,44100000,'2019-02-28','2019-01-24','2020-06-05','',TRUE,FALSE,NULL),
('Hidden Creek (Delta)','7 - Lost','Atlanta, GA',116,1999,NULL,'',NULL,'2019-02-15','2020-06-05','',TRUE,FALSE,NULL),
('Meadow Springs (Delta)','7 - Lost','Atlanta, GA',216,2004,NULL,'',NULL,'2019-02-15','2020-06-05','',TRUE,FALSE,NULL),
('Meadow View (Delta)','7 - Lost','Atlanta, GA',240,2002,NULL,'',NULL,'2019-02-15','2020-06-05','',TRUE,FALSE,NULL),
('Eastwood Village (Delta)','7 - Lost','Atlanta, GA',360,2000,NULL,'',NULL,'2019-02-15','2020-06-05','',TRUE,FALSE,NULL),
('Monterey Village (Delta)','7 - Lost','Atlanta, GA',198,2004,NULL,'',NULL,'2019-02-15','2020-06-05','',TRUE,FALSE,NULL),
('Peachtree Landing (Delta)','7 - Lost','Atlanta, GA',220,2001,NULL,'',NULL,'2019-02-15','2020-06-05','',TRUE,FALSE,NULL),
('1420 Magnolia','7 - Lost','Charlotte-Gastonia-Rock Hill, NC-SC',204,1999,NULL,'',NULL,'2018-02-13','2020-06-05','',TRUE,FALSE,NULL),
('First National','7 - Lost','Richmond-Petersburg, VA',154,1913,NULL,'',NULL,'2018-02-15','2020-06-05','',TRUE,FALSE,NULL),
('Forest Hills at Vinings','7 - Lost','Atlanta, GA',302,1980,NULL,'',NULL,'2018-03-08','2020-06-05','',TRUE,FALSE,NULL),
('Riverside Station Apartments','6 - Passed','Washington, DC-MD-VA',304,2005,312500,95000000,'2026-03-12','2026-01-22','2026-03-05','All Docs Saved, ZRS Managed - Riverside Station: $95M --- ~5.5% Cap in-place 

JS: talked to Zach 2/12, bought by CCG a couple years ago and they did their quick value-add, can still do cabinets closets backsplash tech etc. in units, strong renewals and new leases 2-4%, limited supply, new stuff has absorbed.

JS: location looks interesting, have seen this before, sounds like ccg started renovating it (55% remaining), but size maybe too large...',TRUE,FALSE,''),
('Crossings at Hazelwood','6 - Passed','Nashville, TN',96,2002,156250,15000000,'2026-03-05','2026-02-03','2026-03-05','All Docs Saved - Thanks for reaching out. Guidance is low to mid $30MMs. 

The sellers purchased these assets as student properties in 2022 and converted them to conventional market rate, renovating units and proving out a value-add strategy in the process. There was a partnership dispute along the way, so their eye was taken off the ball from a property level and asset management standpoint. There is opportunity to renovate more units and drastically improve operational expenses. We are underwriting this to a low to mid 6% cap in Y1. 

Let us know how we can help as you dig in. Happy to hop on a call or set up a tour at your convenience.',TRUE,TRUE,''),
('Crossings at Greenland','6 - Passed','Nashville, TN',78,2001,192307,15000000,'2026-03-05','2026-02-03','2026-03-05','All Docs Saved - Thanks for reaching out. Guidance is low to mid $30MMs. 

The sellers purchased these assets as student properties in 2022 and converted them to conventional market rate, renovating units and proving out a value-add strategy in the process. There was a partnership dispute along the way, so their eye was taken off the ball from a property level and asset management standpoint. There is opportunity to renovate more units and drastically improve operational expenses. We are underwriting this to a low to mid 6% cap in Y1. 

Let us know how we can help as you dig in. Happy to hop on a call or set up a tour at your convenience.',TRUE,TRUE,''),
('Cortland Belgate','6 - Passed','Charlotte-Gastonia-Rock Hill, NC-SC',266,2017,225563,60000000,'2026-03-05','2026-01-23','2026-03-05','All Docs Saved 

JS: also university city, closer to thrive. good size. light interior va potential

 - Hey, Ethan. Hope all is well and thanks for reaching out on Cortland Belgate. Guidance is mid $220s/unit, pricing to a low 5% going in cap (tax and insurance adjusted) at an attractive basis relative to replacement cost (16%).
 
Cortland Belgate is a 2017-build, 266-unit community featuring outsized floorplans in the heart of University City, Charlotte’s 2nd largest employment hub (80k jobs). Surrounded by 7M+ SF of office and 3.5M+ SF of retail, the property is anchored by UNC Charlotte, University Research Park, Atrium Health, and 20 Fortune 500 companies, with direct connectivity to I 85, I 485, and the LYNX Blue Line, providing easy access into Uptown (125k+ jobs) and South End (20k+ jobs).
 
Featuring the largest floorplans in the submarket (1,106 SF) while in-place rents trail Class A comps by $190+, the community is positioned for outsized organic rent growth, notably alongside zero units under construction within a 2 miles radius. New ownership also has the opportunity to implement a clean-slate value-add program, including kitchen and bathroom upgrades, modernized amenities, and a tech package, to command average premiums of $150+.
 
Cortland Belgate offers a compelling core plus profile combining durable in place cash flow with embedded upside, supported by strong demand, sustained job growth, and continued population inflows into the University City corridor.
 
Please let us know if you have any questions or would like to schedule a tour.',TRUE,TRUE,''),
('Lemmond Farm Apartments','6 - Passed','Charlotte-Gastonia-Rock Hill, NC-SC',336,2020,220238,74000000,'2026-03-05','2026-01-23','2026-03-05','All Docs Saved 

~20 min east of charlotte, near Allen, don''t know much about this area but looks like nice property. sounds like limited supply, does not sound like any meaningful va, some small in unit things possibly.

 - Lemmond Farm guidance is ~$220K/unit, which prices to a high 4% to low 5% cap and a meaningful discount to replacement cost (15%).
 
Built in 2020, this Class A asset is situated in a supply constrained East Charlotte / Mint Hill corridor, with zero units under construction or proposed within a 5 mile radius. The property benefits from direct access to I 485 and Highway 27, providing sub 30 minute connectivity to Charlotte’s major employment hubs, including University (80k jobs), Uptown (125k jobs), SouthPark (40k jobs), and South End (20k+ jobs).
 
Lemmond Farm is further anchored by the Albemarle Road medical corridor, including the 207K SF Novant Health Mint Hill Medical Center (2 minute drive) and Atrium Health Urgent Care (<1 minute drive), while seamlessly integrated with adjacent commercial developments offering a curated, town center lifestyle.
 
The 336-unit asset is characterized by suburban living, competitive finishes, and stable operating performance, 94% occupied with impressive leasing momentum, as the 10 most recent leases achieved a 12% premium to the current rent roll. Additional upside exists through select interior enhancements, including extending wood look flooring in bedrooms and implementing a tech package to achieve average premiums of $100+.',TRUE,TRUE,''),
('Halston Park Central','6 - Passed','Orlando, FL',288,2007,260416,75000000,'2026-03-05','2026-01-27','2026-03-05','All Docs Saved

JS: near millenia submarket, limited value add (17%)

 No OM Hi Ethan,

 

Pricing guidance for Halston Park Central is $75MM.

 

A few key bullet points to note:

Core-plus, three-story, garden-style multifamily community in the heart of Orlando
Value-add potential with 17% of classic units remaining
Upgraded units achieve up to a $250 premium over classic units
Massive units averaging 1,213 square feet
Prime Orlando location situated between I-4 and SR-441, close to all major employment centers and recreation hubs, including theme parks, hotels, shopping destinations, and Downtown Orlando
Immediate opportunity to implement a bulk internet program ($35/u/mo. net)
$140K+ average resident household income
The Property has tremendous connectivity located in between I-4 (173,500 ADT) and SR-441 (51,500 ADT)',TRUE,TRUE,''),
('Colony at Centerpointe','6 - Passed','Richmond-Petersburg, VA',255,2016,292156,74500000,'2026-03-05','2026-02-09','2026-03-05','All Docs Saved

JS: could be interesting, maybe too large...

 - Ethan -

Thanks for reaching out here - let me know when you have some time to connect and discuss after you have had a chance to digest financials.

Colony at Centerpointe is a 255-unit, 2016 vintage asset located Midlothian, Virginia. The property delivers a compelling combination of strong current performance, value-add upside, and exceptional access to regional employment and amenities. Located within the most rapidly growing submarket of the Richmond MSA,
Guidance is $74,500,000.
Rent Delta to Competitive Set – Colony at Centerpointe is well-positioned for immediate upside, with average rents trailing comparable properties by $250+, allowing future ownership the opportunity to create significant value through a light-lift value-add strategy.
Strong Demographics – The area surrounding Colony at Centerpointe boasts a high concentration of white-collar professionals (77% within 1 mile). Home values are projected to grow 9-14% by 2030, showing strong economic momentum in the area. Average household income in a 3-mile radius of the property is $163,204 and is expected to increase 9.1% by from 2025-2030.
Submarket Fundamentals – Strong historical fundamental trends, averaging 96.0% Occupancy and nearly 5.0% rent growth since the beginning of 2019. There are zero units under construction in the submarket.
Connectivity to Employers – The property is situated minutes from major highway 288 and Route 60, providing quick access to downtown Richmond and surrounding employment hubs. This quick access allows residents to easily commute to top employers in the area, including: Eli Lilly, Google, Lego, VCU Health, HCA Health System, Dominion Energy, Capital One, Federal Reserve Bank, Costar, and Bon Secours St. Francis Medical Center.
High Quality of Life – Colony at Centerpointe is located in the highly desirable Chesterfield County Public School system. Residents benefit from immediate proximity to Westchester Commons, Centerpointe Commons & Colony Crossing, and large grocery stores including Wegmans, Publix, and Aldi',TRUE,TRUE,''),
('Village at Mangonia Lake','6 - Passed','West Palm Beach-Boca Raton, FL',240,2019,287500,69000000,'2026-03-04','2026-01-15','2026-03-04','All Docs saved

JS: not too far, but much further from intercoastal as oversea, location still looks good, much cheaper per unit

 - Hey Ethan! Guidance is ~$290K/door – unbelievable basis for West Palm Beach, especially 5 minutes from downtown wpb
 
+/- 5 cap going in tax adj. but with a lot of low hanging fruit on the operations side. Brazilian international LP took over the deal from the GP/developer (Resia) that is no longer in business, so the property operations can be improved dramatically

Would this be of interest to your team?',TRUE,TRUE,''),
('Pinnacle Ridge','6 - Passed','Dallas-Fort Worth, TX',296,2008,158783,47000000,'2026-03-03','2026-01-23','2026-03-03','All Docs Saved

JS: west of downtown, looks very industrial nearby, good size, possible va

 - Hi Ethan,

We are whispering high $40mm on this one which comes out to low $160k per unit. Cap rate is in the low 5% range. Let me know if you have any additional questions.',TRUE,TRUE,''),
('Ascend Pinegrove','6 - Passed','Washington, DC-MD-VA',288,2025,312500,90000000,NULL,'2026-02-24','2026-03-02','All Docs Saved - $90M

JS: probably not interesting, talked to Jorge on this, growing area, lease up deal, too large...',TRUE,TRUE,''),
('The Kendrick Apartments','6 - Passed','Atlanta, GA',423,1998,200945,85000000,NULL,'2026-01-26','2026-03-02','All Docs Saved - Ethan,

JS: looks like nice location near buckhead and druid hills but size may be too large?

We are excited to bring this opportunity to market in early February.  At that time, you will be able to access financial information as well as schedule a time for a virtual presentation of the opportunity.  A few notes in advance of our broad launch:
 
- Guidance will be mid-$80Ms or $200k+ per unit.  
- This guidance is based on assuming a high-leverage (75%+) loan with a 3.42% rate with ~4 years of term remaining term.  

Our CBRE team looks forward to a future discussion on this loan assumption opportunity which is poised to return elevated levered returns.',TRUE,TRUE,''),
('Green House','6 - Passed','Miami, FL',120,2005,300000,36000000,NULL,'2026-02-10','2026-02-27','All Docs Saved

JS: dadeland, south of miami on way to kendall, midrise

 - Ethan,
 
We’re guiding to $36M ($300k per unit), which is somewhere between a 5.25 – 5.5% cap on a T3 / Pro forma Expenses.
 
We’re normalizing expense because the buyer is not inheriting the current owner’s expense load.
 
Let us know a convenient time to discuss further.
 
Thanks in advance,

Roberto',TRUE,FALSE,''),
('Cortland Santos Flats','6 - Passed','Tampa-St. Petersburg-Clearwater, FL',296,2021,283783,84000000,'2026-02-26','2026-01-22','2026-02-27','All Docs Saved

JS: toured this last week with everyone, nice deal, did not love ths, overall nice deal but probably not for us (too new, large, little va)

 - Guidance is $285-290k per unit here. Please see a few deal points below. Working to get OM finalized and deal room open middle of the week. 

•	Cortland bought from LIV Development during lease-up in early 2022
•	Differentiated product
o	Two 5-story residential buildings w/ tuck-under garages and expansive amenity package
o	Entry drive lined with 2 & 3BR townhomes w/ direct-access garages & private yards
•	Sweet-spot renter profile
o	$116k avg HH income, $100k median, 34 avg age
•	Strategic location
o	0 units under construction w/i 5-mile radius
o	Close proximity to 6 MSF of retail & entertainment and high-profile job centers (USAA, Citi, HCA Healthcare Brandon – 8,700 combined jobs)
o	12-minute drive from Downtown Tampa
•	Interior upside potential
o	Under-cabinet lighting, plank in bedrooms (upper floors), closet systems',TRUE,TRUE,''),
('The Cannon Apartments','6 - Passed','Nashville, TN',168,2023,199404,33500000,'2026-02-26','2026-01-27','2026-02-27','All Docs Saved 

JS: looks like a good location, per Brett (WD) ideally want to be NW (this is NE) but overall sounded like murfreesboro is interesting and desirable, near jersey mikes, aldi, med center etc. but probably too new for us.

 - Ethan,
Working on final details ; plan to launch early next week.  CFO likely early March. Low $200k/door at ~5% in place/tax adjusted cap rate.',TRUE,FALSE,'')
ON CONFLICT (name) DO NOTHING;

INSERT INTO deals (name,status,market,units,year_built,price_per_unit,purchase_price,bid_due_date,added,modified,comments,flagged,hot,broker) VALUES
('Premier at Prestonwood','6 - Passed','Dallas-Fort Worth, TX',208,1995,278846,58000000,'2026-02-26','2026-01-20','2026-02-27','All Docs Saved - $58 million.  Let me know if you would like to set up a tour.

JS: north of dallas near addison, looks like nice location, good retail (whole foods etc.) looks fairly built out so hopefully supply is ok, good size, th units, but looks like va is done and a 4 cap...',TRUE,TRUE,''),
('Pointe Grand Savannah Apartment Homes','6 - Passed','Savannah, GA',307,2021,221498,68000000,'2025-03-26','2025-02-27','2026-02-27','All Docs Saved - Ethan,
 
Pricing is $68M ($236k/unit), which is a stabilized ~5.70% cap rate and can be pushed to a ~6.25% cap by implementing 1/3 of the value-add renovations. Recent leases have been signing ~$50/3.25% higher than in-place average. 
 
Pointe Grand Savannah is well located within Port Wentworth at the intersection of I-95 and Hwy 21 (35k+ cars daily), sitting adjacent to two new major projects: Anchor Park and Meinhard Station. 
 
These projects are bringing 165 acres of newly developed space which will include Top Golf Swing Suites, Savannah Ghost Pirates hockey training facility, Raddison hotel, 88k SF of medical office space, amphitheater, food hall, and regional sports fields & trails. 
 
The property has high-end finishes while being offered at $250 discount to top of market comps, allowing for immediate rental upside Day 1.
 
Savannah is in the midst of generational growth with 8,500 new jobs by Hyundai EV which started production this past year and is expected to lead to total of ~40,000 total new jobs in the metro (20% of current work force). 18,000 of these jobs have already been announced. 
 
Let us know when you are available to tour or discuss further.',TRUE,TRUE,''),
('Solera at Avalon Trails','6 - Passed','West Palm Beach-Boca Raton, FL',74,2024,513513,38000000,'2026-03-11','2026-02-12','2026-02-26','All Docs Saved - Ethan,

JS: 55+ BTR, is BTR interesting for 55+? I feel like less interesting as 55+ does not need as much space and is downsizing, but maybe still prefers a house to apt?

We are guiding to ~5.25% Y1 yield, which equates to about $515k/unit. If you’d like to discuss the opportunity, please let me know.',TRUE,TRUE,''),
('Oversea at Flagler Banyan Square','6 - Passed','West Palm Beach-Boca Raton, FL',251,2020,557768,140000000,'2026-03-03','2026-01-22','2026-02-26','All Docs Saved No OM yet - Pricing guidance is in low-$140M range (mid-$550k/unit | ~$585/PSF), which equates to a tax-adjusted T-3 cap rate of ~4.25%. The Year 1 cap rate is a ~4.9%, reflecting starting rents trended 2.8%, driven by T-90 net renewal trade-outs of 6.7% on 42% penetration (106 units) expiring prior to the analysis start date, along with $55/unit net-cable income fee, stabilized parking income of $85/unit, and fully occupied in-place retail income at the time of sale.',TRUE,TRUE,''),
('Pembroke Pines Landings Apartments','6 - Passed','Fort Lauderdale-Hollywood, FL',300,1997,366666,110000000,'2026-03-12','2026-01-28','2026-02-26','All Docs Saved Target pricing is $110mm, 5 cap in place.  Would you like to arrange a tour?

JS: looks like a nice deal and location but too big?',TRUE,TRUE,''),
('Nova 1400 Apartments','6 - Passed','DaytonaBeach, FL',275,1967,141818,39000000,NULL,'2026-02-04','2026-02-26','All Docs Saved

JS: BTR feel, older deal, zrs managed

from ZRS (Seth): We like the deal. Between us, need roofs asap. There’s not much of a value add play to be had here at the moment. One thing I would look at doing is adding decent size yards. Tons of land and I think you could get a premium. Tends to be a little older demographic due to the single story. Delinquency has been a little higher the past year or two. It’s just a product of the deal type. Overall, we like it and if you’re comfortable coming in without the need for a big value add play and cover roof replacement, take a swing.

 - CCG and ZRS - Hey guys - Thanks for reaching out. Nova 1400 is really unique - single-story concrete construction (BTR feel) on nearly 45 acres.  It''s an irreplaceable site. Great amenity footprint.  High-growth location with upside and projected rent growth.  Guidance around $39MM ($135,000-$140,000/unit range).  6%+ cap going in with upside.

Possible fit for you all? 

Let us know if you''d like to schedule a tour.',TRUE,TRUE,''),
('Riverview Landing @ Valley Forge','6 - Passed','Philadelphia, PA-NJ',310,2005,274193,85000000,'2026-02-25','2026-01-21','2026-02-25','All Docs Saved - Guidance is mid to high $80s. It''s a 5% cap at $85. The property is a true value add in every sense, operational (clear mismanagement) and physical. Arrive at Valley Forge is next door. It was built by the same developer around the same time. Their rents are ~$300 higher and they have smaller units. 
 
Call for offers not set but likely late February.',TRUE,TRUE,''),
('Allure at Edinburgh','6 - Passed','Norfolk-Virginia Beach-Newport News, VA-NC',280,2024,325000,91000000,'2026-02-25','2026-01-13','2026-02-25','All Docs Saved - 
Thanks for the interest in this exceptional opportunity - here’s the rundown on Allure at Edinburgh. This is Chesapeake’s newest Class A multifamily community, delivered in 2024/2025 and ideally located within one of Hampton Roads’ most affluent, supply-constrained neighborhoods. Notably, Allure is surrounded by multi-million-dollar homes and benefits from top-tier public schools-Hickory schools are all rated A+- with area household incomes at $168K (5-mile) and up to $211K (0.25-mile).  Some of the recent financial and operational highlights: 

•	Currently Stabilized at 99.3% Occupancy (1/7/26 rent roll) . Reached stabilization in September of 2025.  Leased 275 units in 11 months 
•	In-Place Rent: $2,068/mo ($2.13/SF), with Market Rent at $2,162/mo ($2.22/SF) and embedded upside as new leases are signed at market.  Last two leases of each floorplan signed averaged $2,162 or full market.  There are no concessions on the T-3
•	Lease renewals and new move-ins are being signed at ~4.5-6%
-	with an occupancy at 99% and already achieving full market rents, there is strong support to push even more
•	Extremely favorable rent-vs-own premium average in-place rent is $2,068 vs. ~$7,900 monthly homeownership cost nearby, supporting deep rental demand

Guidance: We are guiding to $91,000,000 ($325k/unit), reflecting a 5.75% cap rate on T1/T12 financials and a mid 5% cap rate on tax adjusted first year. 

Deal Docs (OM, DD, etc.): https://clientportal.berkadia.com/opportunities/006Pf00000cpZXJIA2

Quick Overview: 
•	280 Units | Built 2024 | 99.3% occupied 
•	Irreplaceable offering: Chesapeake’s newest, market-leading Class A community in a true high-barrier submarket with minimal new supply. This District is no longer zoning land for apartments
•	Premier Location: Steps to Greenbrier Business District and major employment drivers, easy access to I-64, Virginia Beach Town Center, healthcare, and Fortune 500 employers 
•	“A” Rated Public Schools: All assigned schools rated “Distinguished” 
•	Best-in-class amenities: saltwater resort pool, golf simulator, large fitness center, movie theater, pet spa and multiple resident workspaces in each building

Happy to walk through our underwriting or get deeper on any details- let me know how I can help.
Best,',TRUE,TRUE,''),
('Arcadia','6 - Passed','Nashville, TN',81,2022,185185,15000000,'2026-02-25','2026-01-21','2026-02-25','All Docs Saved

JS: near hendersonville, on other side from cantare at indian lake village, looks like older area but good retail and built out. probably too small

 - Ethan—thanks for reaching out. Guidance is low $190’s per door which we have underwritten to a low-5% going-in cap and a high-5% Y1 cap rate.

Let us know how we can help as you dig in. Happy to hop on a call to discuss or set up a tour at your convenience.',TRUE,TRUE,''),
('Park Avenue at Boulder Creek Apartments','6 - Passed','Houston, TX',292,2009,160958,47000000,'2026-02-25','2026-01-22','2026-02-25','All Docs Saved  - Thank you for your interest in Park Avenue at Boulder Creek, a 292-unit, 2009-vintage luxury garden-style community.

Below are a few Key Investment highlights:

•	Value-Add Upside: Classic interiors remain original, creating a clear path to drive premiums through upgrades such as stainless appliances, quartz/granite-style counters, tile backsplash, and modern finishes.
•	Significant Discount to Replacement Cost: Replacement cost is estimated at ~$203k per unit, supporting compelling basis relative to new construction economics.
•	Limited New Supply: There is no new competitive supply within three miles, positioning the asset favorably for occupancy and rent growth as the pipeline remains constrained.
•	Large Floor Plans + Strong Amenity Package: Spacious layouts (avg. ~1,024 SF) and a robust amenity set including a resort-style saltwater pool, fitness center, dry sauna, business center, sand volleyball, and more.

We are guiding to $47M / $161k per unit. Please let me know if you would like to schedule a tour.',TRUE,TRUE,''),
('Avilla Lakeridge','6 - Passed','Fort Worth, TX',170,2023,270588,46000000,'2026-02-25','2026-02-17','2026-02-25','All Docs Saved

JS: brunmar mentioned these

 - Below is pricing and a few highlights.   Let me know if you would like to discuss further.

The asking price is $105,500,000 for the package which breaks down to $59,500,000 ($273k/unit) for Traditions and $46,000,000 ($270k/unit) for Lakeridge.   This pricing is below replacement cost, which is about $300k/unit. They both are operating very well.  Lakeridge is 97% occupied today and Traditions 96% with very minimal concessions.   These will be mid 5% caps.
Key Highlights:
•	Exceptional locations in Grand Prairie and Arlington/Mansfield ISD
•	Strong Submarkets with Minimal Concessions at the Properties
•	Fully stabilized since 2023
•	Single-Plat, Purpose-Built Communities
•	Pricing Below Replacement Cost
•	Property Tax Appeals are in process with significant reductions projected by the tax consultant
 
Please reach out with any further questions or to set up a tour.',TRUE,TRUE,''),
('Avilla Traditions','6 - Passed','Dallas-Fort Worth, TX',218,2023,272935,59500000,'2026-02-25','2026-02-17','2026-02-25','All Docs saved

JS: brunmar mentioned these


 - Below is pricing and a few highlights.   Let me know if you would like to discuss further.

The asking price is $105,500,000 for the package which breaks down to $59,500,000 ($273k/unit) for Traditions and $46,000,000 ($270k/unit) for Lakeridge.   This pricing is below replacement cost, which is about $300k/unit. They both are operating very well.  Lakeridge is 97% occupied today and Traditions 96% with very minimal concessions.   These will be mid 5% caps.
Key Highlights:
•	Exceptional locations in Grand Prairie and Arlington/Mansfield ISD
•	Strong Submarkets with Minimal Concessions at the Properties
•	Fully stabilized since 2023
•	Single-Plat, Purpose-Built Communities
•	Pricing Below Replacement Cost
•	Property Tax Appeals are in process with significant reductions projected by the tax consultant
 
Please reach out with any further questions or to set up a tour.',TRUE,TRUE,''),
('The Bowie Apartments','6 - Passed','Atlanta, GA',350,1980,145714,51000000,'2026-03-03','2025-01-09','2026-02-24','All Docs Saved - 

JS: in-between veridian and river vista, looks interesting 

2026 - Pricing guidance here is 145-150k/door. Yes, that is below the loan balance and yes, the lender knows this and has approved of the sale. The sponsor still has title, is our client, and is running the sales process with us- under lender approval. The basis is undeniably amazing, and it does qualify for agency debt or any bridge vehicle. 

I am available for tours- this one will likely be competitive so let me know if you need anything before the CFO date. 


2025 - Guidance will be around $170k/door which is a 5.6% cap at 95% occupancy (now it is 90%) and 2% bad debt (now it is 4.5%).',TRUE,TRUE,''),
('Elliot Apartments on Abernathy','6 - Passed','Atlanta, GA',228,1976,NULL,NULL,NULL,'2025-12-10','2026-02-24','Coming Soon

JS: formerly 550 abernathy sbi owned',FALSE,TRUE,''),
('Elme Bethesda','6 - Passed','Washington, DC-MD-VA',193,1986,310880,60000000,NULL,'2025-09-16','2026-02-24','All Docs Saved - 1.	Elme Watkins Mill – mid $40MMs, ~$210K/Unit, upper-5% to 6% in-place tax adjusted cap rate
2.	Elme Bethesda – ~$60MM, $310K/Unit, upper-5% to 6% in-place tax adjusted cap rate
3.	Elme Germantown – mid $50MMs, ~$250K/Unit, upper-5% to 6% in-place tax adjusted cap rate
4.	Kenmore – mid $70MMs, ~$200K/Unit, upper-5% to 6% in place tax adjusted cap rate
3801 Connecticut - mid $70MMs, ~$240K/Unit, upper-5% to 6% in place tax adjusted cap rate',TRUE,TRUE,''),
('The Collection at Scotland Heights','6 - Passed','Washington, DC-MD-VA',74,2023,391891,29000000,NULL,'2026-01-21','2026-02-24','All Docs Saved

JS: new TH deal in waldorf at new pricing, prob not for us
- Guidance Pricing is $29M+.
 
Guidance Pricing:
·         $29M+ ($391,892/unit)
·         Year 1 NOI of $1,647,125
·         5.72% Year 1 Cap Rate (Tax Adjusted)
·         7% Year 1 Cash on Cash Return | 8.62% Average Cash on Cash Return
·         Mid-Teens IRR (Levered)
·         90% Leased/86% Occupied (recent property management change)
·         RCM Deal Room- The Collection at Scotland Heights Landing Page
·         CFO- early March
 
Please let us know if you have any questions or wish to schedule a tour.
 


CBRE brought out in 2024 for $34M',TRUE,TRUE,''),
('Masons Keepe','6 - Passed','Washington, DC-MD-VA',270,2004,314814,85000000,'2026-03-03','2026-01-21','2026-02-24','All Docs Saved Ethan,

Good morning - We are guiding to $85mm or $315k/unit which is a 4.97% cap on T-3/T-12 re tax adjusted. Property has 78% 2BR and larger.  Amenities & Units are largely untouched since 2005 (1/4 of units have new appliances and are getting $140 premium for it).  Stairs, HVAC, water heaters & roofs substantially all replaced in last few years.  Seller is HNW families who built it originally but upside in operations + Bozzuto managed.',TRUE,TRUE,''),
('MAA Hermitage','6 - Passed','Raleigh-Durham-Chapel Hill, NC',194,1988,201030,39000000,'2026-02-25','2026-01-21','2026-02-24','All Docs Saved

JS: looks like good location, residential but not too far from retail, bass pro shops to north and trader joes southeast, looks like a nice va story, could be interesting

 - Hey Ethan, 

We’re guiding $39M ($200k/unit) which is a 5.25% T3/T12 cap rate (tax-adjusted). CFO is 2/18. See some details below and give me a shout when you’ve had a chance to go through it. 

MAA Hermitage has been institutionally maintained for over 35 years and has never received a full unit renovation. It’s the only 1980s vintage asset in the immediate area and maintains a $200 rent gap to proximate newer vintage assets.  

No poly piping, new roofs, and an unbeatable Cary location minutes from RTP & barbelled by SAS HQ and MetLife Global Technology Hub.  

5-year agency debt with a buy down is sizing to 65% leverage at a 4.90% all in rate. Additional floating rate options available reaching 70%+ leverage.  The W&D debt matrix is available in the deal room. 

We’ve provided some additional details below but let us know if you would like to schedule a call or tour. 

MAA Hermitage / Core Cary Location / 1988 Vintage / 194 Units
96% Occupied and <0.25% Bad Debt over the T12
•	Truly a “blank slate” value-add opportunity with little deferred maintenance and majority classic units 
o	$4.3M invested by current ownership including all 14 roofs replaced from 2014-2021
o	Smart Home upgrades in 2023 including smart locks, thermostat, leak detectors, and two smart lights
o	Preservation improvements from 2016-2022 to replace appliances and add LVP flooring in wet areas of most units
o	Washers/Dryers in majority of units (97%)
•	AT&T Cell Tower lease generating $47K ($240/unit) annually
•	Situated ideally for easy access to I-40, Cary Pkwy, Harrison Ave, and all Cary has to offer – ranked the #5 Best Place to Live in the U.S. by U.S. News & World Report
o	3-Mile average HHI of $121K
o	Zoned schools include Reedy Creek Elementary (6/10), Reedy Creek Middle (8/10), and Cary High School (7/10)
•	Insulated by affluent neighborhoods with no multifamily supply pressures nearby
o	Surrounded by recent home sales of $800K-$1M+ and 0 units under construction in a 2-mile radius 
•	10-minute drive from Research Triangle Park (60K Jobs), RDU’s largest employment node 
o	5-miute drive to SAS Global HQ (4,000 employees) and MetLife Global Technology Hub (2,600 employees)
•	Exceptional Access to Various Retail & Dining Options – 3.2M+ SF of Retail Within a 3-Mile Radius
o	Anchored between The Arboretum and Park West Village: combined 685K SF of Class A retail including Trader Joe’s, Target, Ruth’s Chris Steak House, Starbucks, and more',TRUE,TRUE,''),
('Crowne Oaks Apartments','6 - Passed','Greensboro--Winston-Salem--High Point, NC',192,1996,197916,38000000,NULL,'2026-01-16','2026-02-24','All Docs Saved - $38m. Let me know if you want to catch up to discuss… 

JS: don''t know location but 9ft ceilings, va potential, limited supply per broker and good size, could be interesting',TRUE,TRUE,''),
('29 Fifty Apartments','6 - Passed','Fort Worth, TX',224,1996,214285,48000000,'2026-02-19','2026-01-15','2026-02-20','All Docs Saved - - $48 mm strike, let us know if you need anything else.

JS: north of FW, inbetween Dallas and FW near airport, dont know location but size is interesting, near grapevine hs which looks to be a well ranked school. va potential',TRUE,TRUE,''),
('Anaberry Forest (3/3) Gwinnett Portfolio','6 - Passed','Atlanta, GA',110,1985,NULL,NULL,NULL,'2026-02-11','2026-02-19','All Docs Saved (3/3) Waiting til Will Tours',TRUE,TRUE,''),
('Cacema Townhomes','6 - Passed','Orlando, FL',176,2024,375000,66000000,'2026-02-18','2025-12-16','2026-02-18','All Docs Saved

JS: new ths in kissimmee. 

 - Thanks for reaching out on this one! Our pricing guidance on Cacema Townhomes is $66M-68M, which is approximately $270 PSF, reflecting a 5.50% proforma cap rate assuming today’s rents and stabilized operations.
Cacema is a fully amenitized build-to-rent community featuring premium 3- & 4-bedroom townhomes with garages, private backyards, and luxury finishes, complemented by resort-style amenities including a pool, fitness center, lakeside lounge, clubhouse, and walking trail. The Property benefits from exceptional connectivity with direct highway access to over 50,000 businesses and 620,000 employees within 30 minutes, including Disney World and Universal Studios. Furthermore, it is the only product of its kind in its micro-location as all the competitive supply is higher-density apartment product, making it a truly unique and irreplaceable asset.
The OM and financials will be available at the beginning of the new year. Let us know if you would like to set up a time to discuss the opportunity.',TRUE,FALSE,''),
('Tate Tanglewood','6 - Passed','Houston, TX',431,2016,187935,81000000,'2026-02-17','2026-01-22','2026-02-18','All Docs Saved - $188k/unit.  Thanks guys',TRUE,TRUE,''),
('Green Hills (1/3) Gwinnett Portfolio','6 - Passed','Atlanta, GA',12,1976,NULL,NULL,NULL,'2026-02-11','2026-02-18','All Docs Saved - (1/3)  Waiting til Will Tours',TRUE,TRUE,''),
('Tanaga Forest (2/3) Gwinnett Portfolio','6 - Passed','Atlanta, GA',80,1984,NULL,NULL,NULL,'2026-02-11','2026-02-18','All Docs Saved (2/3) Waiting til Will Tours',TRUE,TRUE,''),
('Jefferson Northlake','6 - Passed','Dallas-Fort Worth, TX',360,2024,250000,90000000,'2026-02-13','2026-01-07','2026-02-17','All Docs Saved - $90 million.  Please let me now if you would like to set up a tour.

JS: north of FW near texas motor speedway, too new and too big',TRUE,TRUE,''),
('Kingston at McLean Crossing','6 - Passed','Washington, DC-MD-VA',319,2018,457680,146000000,NULL,'2025-09-23','2026-02-13','All Docs Saved  - Thanks for reaching out, we are guiding to high $140’s ($460K per unit), which is just shy of a 5% cap rate on in-place T3/T12 real estate tax adjusted.  The asset maintains high occupancy (currently 96% occupied) and above 60% retention historically, given the location adjacent to Silver line metro, Capital One global HQ, and sitting within the Mclean school district (A Niche rated) - which many of the comps do not offer.  Avg HHI over $200k.  Built in 2018 the asset offers value add upside in all of the units (replacing carpet in the bedrooms, lighting upgrades, bathroom upgrades, closet systems, etc) and common area FF&E refresh.  Some newly delivered comps are achieving several hundred dollars a month higher in rent.

Happy to jump on a call. We also launched E lofts which from a deal size perspective could be a nice fit - $75M ask.',FALSE,TRUE,''),
('Waverley Place Apartments','6 - Passed','Naples, FL',300,1990,250000,75000000,'2026-02-12','2026-01-09','2026-02-12','All Docs Saved

JS: ne from naples not quite to north naples, inland a good bit, looks like we looked at a couple other deals around here.

 - Guidance is $75M/$250k/unit, 5.5 cap with adjusted taxes. Collier County has one of the lowest tax rates in the state leading to higher per unit pricing. Fully reassessed taxes are $1900/unit, additional tax savings can be achieved through a purchase price allocation strategy, brining taxes closer to $1700/unit. 

There is a significant value add opportunity through interior renovations and additional other income; bulk cable, valet trash and covered/reserved parking. With less than 7,000 units of attainable housing in Collier County and the increasing demand, Waverley is a great opportunity to gain exposure to a growing segment of the attainable housing market in Naples. The supply of new product caters to the high end of the market leaving an opening for a value add program that builds to the middle and targets a renter looking for renovated product that currently is in limited supply among the direct comps. Located near several A rated schools and multiple major employers: Arthrex, NCH, Amazon, ASG Technologies and broader service sector employment. 
Would you like to schedule a tour or jump on a call early next week to talk through the opportunity?',TRUE,TRUE,''),
('The Colonel','6 - Passed','Washington, DC-MD-VA',70,2015,442857,31000000,'2026-02-19','2025-01-07','2026-02-12','All Docs Saved 

Great to hear from you.  I think this deal would be a good fit for you guys.  We are targeting $30m for the deal which is a 6.0% cap on our proforma.  The property has largely taken care of the delinquency issues that were hanging over since covid and operations are now back to normal.  There is a great renovation upside story by renovating the unit interiors which can achieve a $200 premium based on our rent comp study.  The property also backs up to Blagden Alley which is a substantial amenity to the residents.  There is a lot to like on this deal.  We should be in the market with the OM and financials next week.',TRUE,TRUE,''),
('University Hill Apartments','6 - Passed','Raleigh-Durham-Chapel Hill, NC',269,2020,327137,88000000,'2026-02-11','2026-01-06','2026-02-11','All Docs Saved - $88-90 million

JS: just northeast of haven in large retail area with target sams club etc. looks too large and new',TRUE,TRUE,''),
('Melrose on the Bay Apartment Homes','6 - Passed','Tampa-St. Petersburg-Clearwater, FL',358,1987,164804,59000000,'2026-02-10','2026-01-08','2026-02-11','All Docs Saved

JS: location looks a little rough, probably want a better location for older va deal like this

 - Hi Ethan,

Great assumable debt (see below) and a very solid current ownership group. 

Guidance pricing: ~ High $160’s/Unit (Last 80’s Deal in the area sold for $205k/unit)

Melrose on the Bay Landing Page
Melrose on the Bay - Click to Sign the C.A.

•	Strong Performance: 93.9% T12 occupancy, $1,528 avg. Actual T12 Rent Growth of 4.2% 
•	Assumable Freddie Mac Loan: 35-year amortization, ~72% LTV, 5.10% interest rate, multiple years interest-only
•	Unit Mix: 65% two- and three-bedroom floor plans, all with in-unit washer/dryer
•	Major recent CapEx ($6.7M) including ALL New Roofs, exterior paint, landscaping, HVAC upgrades and more
•	Value-Add Potential: Majority of units with original interiors; proven rent premiums of $180/month on renovated units
•	Prime Location: Minutes to Clearwater Beach, St. Pete–Clearwater Airport, major employment hubs (BayCare, Raymond James, Jabil)

Rent Upside Opportunity:
•	Current average rent: $1,528 vs. competitive set average: $1,917 (2BD/2BA comps Average age of comps is 1983)
•	Submarket renovated 1BD units average $1,578, while Melrose averages $1,368 – $210/month below comps
•	$389/month gap on 2BD/2BA units and $309/month gap on 3BD/2BA units compared to renovated comps
•	Significant room to capture premiums through interior upgrades, amenity enhancements, and upside through trash reimbursement and internet program rate increase.

Let us know when we can get a tour on the books once you dig in.',TRUE,TRUE,''),
('Collins Crossing Apartments','6 - Passed','Raleigh-Durham-Chapel Hill, NC',270,1985,129629,35000000,NULL,'2026-02-02','2026-02-10','All Docs Saved

JS: could be a nice small value add older opportunity 

 - Ethan – Are you around this week for a call to chat through this one?
 
Thanks for reaching out. Guidance here is $130k-$140k per unit, which translates to a 20% IRR if you go with new debt and even higher if you choose the assumption route. The owner here is going to meet the market on this one, so would definitely dig in.
 
Between current ownership and prior ownership, this asset has received over $8M of defensive capital spent into the asset. This allows new ownership to inherit a very clean asset, with 9 foot ceilings, in a high barriers to entry submarket, with a meaningful rental gap. New ownership can focus solely on interior renovations while taking advantage of the interior and operational upside. Furthermore, there is an optional, accretive agency loan assumption with a 3.65% fixed rate. See below for high-level investment highlights and a link to the deal room where you can access all relevant materials. Let us know what you need from us as you’re digging in.
 
Collins Crossing // 270 Units // Carrboro, NC
 
•	C&W recommends that new ownership implements a value-add program to unit interiors by renovating units to a market-comparable standard with quartz countertops, white shaker cabinetry, kitchen tile backsplash, and gooseneck faucets to capture $100+ rent premiums and increase overall revenue by $325k+.
o	Units currently feature stainless steel appliances, laminate countertops, vinyl plank flooring, and upgraded light fixtures.
•	Comparable properties in the area provide ample rental headroom as Collings Crossing trails the submarket average rents by $145+ and the submarket leader (Ashbrook) by $380+.
•	Current ownership has injected over $1.9M into the asset since acquisition in 2019 for items such as HVAC and water heater replacements, unit upgrades, general building exterior repairs, and landscaping, allowing new ownership to focus the majority of CapEx on renovating interiors to a market-supported finish level. 
o	Prior to their ownership, the previous owner held the asset for 8 years and injected $6M into the asset over their hold period. Including new roofs, new windows, new siding, new asphalt, significant common area and clubhouse improvements, etc. 
•	The 5-mile radius surrounding Collins Crossing boasts a population with an average household income of $120k+, 74% college educated, and 48% renters.
•	The Chapel Hill/Carrboro submarket ranked #1 among all RDU submarkets in Q3 2025 in average occupancy (95.1%), annual occupancy growth, and annual rent growth.
o	Rents have grown 27% since 2020 and are projected to grow an additional 14.3% by 2029.
•	The property benefits from a high-barriers to entry story as only 94 units have been delivered since 2018 within a 2-mile radius of the property, with no large developments currently underway. The next newest deal prior to that, was built in 1997. 
•	Residents of Collins Crossing enjoy close proximity to the area’s top retail and dining hubs which are anchored by tenants such as Chick-fil-A, Starbucks, Trader Joe’s, Wegman’s, Fresh Market, Carolina Brewery, Panera Bread, and Chipotle.
o	Additionally, Collins Crossing site just minutes away from UNC’s campus and hospital, which employs 4,000+ faculty and 9,000+ staff members.',TRUE,TRUE,''),
('Cortland University North','6 - Passed','Charlotte-Gastonia-Rock Hill, NC-SC',300,1989,170000,51000000,NULL,'2026-01-22','2026-02-10','All Docs Saved - Guiding low 170s/unit which is 5.3-5.4% cap or so.

JS: university city north, I think this area is better than thrive? could be interesting - cap rate 5.35 and YOC 5.7 so should underwrite',TRUE,TRUE,''),
('Riverland Apartments','6 - Passed','Fort Lauderdale-Hollywood, FL',276,2021,NULL,NULL,NULL,'2026-01-22','2026-02-05','Coming Soon Signed CA

JS: location looks a little rough but maybe ok, need more info on pricing etc.',FALSE,TRUE,''),
('Bell Arlington Ridge Apartments','6 - Passed','Washington, DC-MD-VA',217,2010,391705,85000000,NULL,'2026-01-23','2026-02-04','All Docs saved 

JS: right off 395 by army navy club, 100% VA opportunity, looks interesting, maybe too big?

 - Hi Ethan,

Mid $80M which is a high 4% in-place with value-add upside in a great little pocket. Seller is Bell and materials will be ready after NMHC. Let me know if you want to tour.',FALSE,TRUE,''),
('Metro 710','6 - Passed','Washington, DC-MD-VA',104,1968,201923,21000000,NULL,'2026-01-23','2026-02-03','All Docs Saved, No OM - $21M --- 6% Cap in-place. 

old high rise downtown silver spring, probably not for us',FALSE,TRUE,''),
('Everly','6 - Passed','Charlotte-Gastonia-Rock Hill, NC-SC',253,2024,367588,93000000,NULL,'2025-12-18','2026-02-03','All Docs Saved - Mid $90mm range 

JS: south end, nice deal and location, likely too big and too new...',TRUE,TRUE,''),
('Azure Carnes Crossroads Apartments','6 - Passed','Charleston-North Charleston, SC',295,2020,240677,71000000,NULL,'2026-01-23','2026-02-03','All Docs Saved No OM

JS: looks like nice location near publix and hosptial and new developments but lots of nearby land. in Carnes, north of summerville.

 - Ethan - Thanks for reaching out. Guidance here is ~$240K/door and reflects a 5% in place cap rate. We are projecting an upper 5% cap rate YR1 through the implementation of a light value-add and some organic rent growth. 92% of the supply has been absorbed in Summerville and the future pipeline is limited in our 5 mile radius.  

With the largest floorplans in the comp set, with elevators and being walkable to a brand-new Publix, this asset is poised for incredible rent growth. HelloData projects a 7% increase in 2026 and an 8.3% increase in 2027. 

The most relevant comp is Solay Carnes Crossroads; it’s the same Davis Development product and is achieving a +$300 premium over the current rent roll. 

CFO date is targeted to be the first week of March. Let me know when you have availability to discuss.',TRUE,TRUE,''),
('The Skylark','6 - Passed','Atlanta, GA',319,2020,200000,63800000,NULL,'2026-01-21','2026-02-03','Coming Soon Signed CA

JS: looks like decent location, se of downtown, near beltline, sf looks ok nearby, size is good but maybe limited va

Guidance is $63.8M / $200K per unit with initial yields in the high 4% range.  We are seeing strong operational momentum at the asset and across the submarket as the supply pipeline moderates and absorption stays at historic levels throughout the market.  

With the completion later this year of the adjacent Southside Beltline trail, there will be continuous connection all the way to Piedmont Park and beyond.  Very strong growth prospects with incredible basis on the Southeast’s best piece of public infrastructure in a very desirable part of Atlanta’s dynamic eastside.

Let us know when you’re able to catch up on it and happy to discuss in further detail.  We haven’t released any financials yet, but you can execute the CA and as soon as they’re available you’ll be notified.',FALSE,TRUE,''),
('1160 Hammond','6 - Passed','Atlanta, GA',345,2014,263768,91000000,NULL,'2026-01-23','2026-02-03','All Docs Saved  - Ethan,

JS: perimeter center, nice location and deal but size likely too large 

Thanks for your note. Guidance on 1160 Hammond is low $90M’s, or ~$265k/unit. This represents a compelling investment opportunity for several reasons:

•	Value Add Potential
o	2014 Vintage with impressive physical plant - 16K SF clubhouse, 10’-14’ ceilings and larger average unit size.
o	With in-place rents of ~$1,750, there is $400+ of headroom in rents compared to newer product in the submarket.

•	Resilient Operations
o	95% Physical Occupancy in the T3
o	Limited A/R – only 4 residents past 60 days late
o	Bulk WiFi implemented in Dec 2025 – providing $240K of additional revenue

•	Submarket Positioning
o	“Main and Main” location in Sandy Springs with immediate access to I-285/GA-400
o	Walkability to Pill Hill, several corporate HQ’s and mass transit (MARRTA)
o	25% Discount to replacement cost in a submarket with minimal new supply',TRUE,TRUE,''),
('The District at Windy Hill Apartments','6 - Passed','Atlanta, GA',284,2019,264084,75000000,'2026-02-10','2026-01-08','2026-02-03','All Docs Saved - Ethan,

JS: across the street from Belmont Place

Guidance is mid-$70m’s or ~$265k/unit. The asset is performing well and has a 96% occupancy trend with no bad debt.

Opportunity Highlights
•	Extremely limited historical and future supply pipeline 
o	25%+ discount to midrise replacement cost
•	$500 rental headroom to new comps
•	Direct access/visibility to I-75/I-285
o	Walkability The Battery/Truist Park
•	Discount to recent submarket trades
o	Revel Ballpark / Shadowood Heights – both are $300K+/unit

Is there a convenient time to discuss in more detail?',TRUE,TRUE,''),
('Belmont Place','6 - Passed','Atlanta, GA',326,2004,245398,80000000,NULL,'2026-01-23','2026-02-03','All Docs Saved No OM - -	Belmont Place: $80M, mid $240k’s per unit, low 5%’s cap rate in place

JS: near truist park, continue current va program, bulk is phasing in',TRUE,TRUE,''),
('Village on the Green Apartments','6 - Passed','Atlanta, GA',216,2004,134259,29000000,'2026-02-04','2025-12-11','2026-02-03','All Docs Saved 

JS: Greenbrier, not sure about location (near airport se atl)
 
Ethan - Glad you’re taking a look!
 
Guidance here is $135-145k/unit which is sub-$130/SF.  The basis feels great for 2004 product (9’ ceilings, hardi/brick siding) and $1500+ rents.  The cap rate is easily north of 7% if operations are stabilized.  
 
Here are some quick highlights:
•	Long-term Ownership: The current owner purchased the property in 2017 and selling due to a fund expiration.
•	Taxes Under Appeal: Current ownership is appealing the 2025 value.
•	Large Floorplans: Avg unit size is 1,106 and offers unique 2BR/2.5BA townhomes with garages.
•	100% Classic Interiors:  With the exception of updated flooring and typical turn items, the current owner has not renovated any of the units.
•	Quality Construction:  Built by a well-known Atlanta-based developer, Norsouth, the gated community offers a unique neighborhood character.
•	Significant Area Improvement: $600M development planned on 26 acres within a mile of the property.
 
We plan to collect offers in late January.  Let us know if you have any questions or if you’d like to setup a tour.  Thanks!',TRUE,TRUE,''),
('Gables Montclair','6 - Passed','Atlanta, GA',183,2001,262295,48000000,NULL,'2026-01-21','2026-02-03','All Docs Saved

JS: looks very interesting except for ground lease, is that a non-starter? nice location near emory, large th units, va story etc.

 - Gables Montclair is a highly differentiated infill Atlanta asset, offering a predominantly townhome-oriented product within one of Atlanta''s most prolific EDs & MEDS hubs.
Scheduling tours now | CLICK HERE to schedule
Pricing guidance and highlights below: 
Rare Intown Townhome Rental Product:
•	70% townhome with average unit size 1,700 SF
•	Townhome units include 1-and-2-car garages
•	All bedrooms have in-suite bathroom
Value-add Outside
•	Organic rent growth with expiring leases $88 below todays average
•	$900 below TH rents at Bell Rock Spring (best comp)
•	Most units are original / some LVT flooring  (less than 25%)
 Well-Preserved Institutional Asset
•	Built/owned by Gables since 2002
•	+$1M capital investments past three years
•	100% roof replacement in 2024
 Stable Operations:
•	97% Occupied
•	Virtually NO BAD DEBT <$6,000 90-day delinquent (100% attributed to 1 tenant)
 Pricing Guidance:
•	High $40Ms; high 4-cap in-place
•	Leasehold intertest - property sits on a 55-yr ground lease
•	Scheduling tours now | CLICK HERE to schedule
•	Call For Offers - TBD',TRUE,TRUE,''),
('Artesia Big Creek','6 - Passed','Atlanta, GA',269,2020,334572,90000000,NULL,'2026-01-20','2026-02-03','All Docs Saved 

JS: looks interesting, nice location but too large and new

- Ethan,

Pricing is $90M ($335K per unit), which is a 5.30% Year One Cap Rate.

This asset sits along the Big Creek Greenway and is across the street from Halcyon, a 350K+ SF, 99%-occupied mixed-use destination anchored by Trader Joe’s. Also, Artesia Big Creek is in Alpharetta, but unincorporated Forsyth County (vs. Fulton) resulting in a lower millage rate, more favorable assessments, and $15K+ per unit valuation advantage.

This truly is a fantastic location in Atlanta’s highest barrier submarket with only ~77 units delivering per year since 2005. Alpharetta is ranked #1 for best places to live in GA and boasts household incomes of ~$197K.

Built by Davis Development in 2020 and institutionally owned by Starlight since 2021, Artesia Big Creek has consistently outperformed the market with ~95% average occupancy, minimal concessions (~0.5%), and bad debt (~0.3%).

When are you available to discuss and/or tour?',TRUE,TRUE,''),
('Villas at West Ridge','6 - Passed','Atlanta, GA',230,2002,184782,42500000,NULL,'2026-01-23','2026-02-03','All Docs Saved No OM - -	Villas at West Ridge: Low-Mid $40M’s, mid $180K’s per unit, mid 5%’s cap rate in place

JS: west of atl, not far from 6 flags, continue va program, nice size / b-plan but don''t know about location does not look ideal',TRUE,TRUE,''),
('Sweetwater Creek Apartments','6 - Passed','Atlanta, GA',240,2003,185416,44500000,NULL,'2026-01-23','2026-02-03','All Docs Saved , No OM - -	Sweetwater Creek: Mid $40M’s, mid $180K’s per unit, mid 5%’s cap rate in place


JS: west of atl, not far from 6 flags, continue va program, nice size / b-plan but don''t know about location does not look ideal',TRUE,TRUE,''),
('The Pynes by Trion Living','6 - Passed','Atlanta, GA',267,1973,84269,22500000,'2026-02-10','2026-01-07','2026-02-03','All Docs Saved - - $85k/door, $10M below the loan amount!!

JS: also west alt near six flags, not sure of location, does not look like a very nice area and property, low basis',TRUE,TRUE,''),
('Retreat at Nona Place','6 - Passed','Orlando, FL',288,2018,277777,80000000,'2026-02-11','2026-01-08','2026-02-03','All Docs Saved - Ethan – thanks for reaching out. 

Guidance is $80-82M, around $280k per unit. Few key deal points below – 

•	2018 vintage, Bainbridge lakefront execution, village center feel
o	Submarket-leading walkable retail, including grocer – 178K SF (half of which is UC) 
o	Upside – plank in bedrooms, bulk Wi-Fi, closet systems (18% complete)
•	Starlight acquired out of lease-up and has a loan maturity in Q2
o	Changed management companies (Bainbridge to Avenue5) 60 days ago
o	Bainbridge has two other owned/managed properties in the submarket
•	Primo location in Lake Nona surrounded by top neighborhoods ($984k avg. home sale last 12 months) and across from the High School (A-Rated)
•	Clear end in sight on pipeline/absorption, with sizable high-profile jobs incoming (breakdown on 26-27 of OM)
o	Siemens Energy relocating to Lake Nona Town Center in 2027 (~3,000 jobs, 242K SF)
o	AdventHealth Lake Nona opening a 10-story, $423M campus in 2026 (~1,500 jobs)
o	United Airlines $315M operations hub under construction at Orlando International Airport (~1,000 jobs)
o	Nemours Children''s Hospital $300M expansion opening in Q1 2028 (~1,000 jobs)

Materials should be out tomorrow, Monday at latest.

Let me know a good time to discuss.',TRUE,TRUE,''),
('Azul at Viera Apartments','6 - Passed','Melbourne-Titusville-Palm Bay, FL',166,2020,295180,49000000,'2026-02-12','2026-01-08','2026-02-03','All Docs Saved - Guidance on Azul at Viera is $49M / $295K per door which is a low-5% trailing, tax and insurance adjusted cap rate. The Property has averaged 95% occupancy over the T12, with in-place rents of $1,952 ($2.07 psf) which continue to trend upward as the surrounding newer comps are offering asking rents in the $2,300 - $2,500 / $2.30 psf+ range. The OM should be available this week.

The property is a boutique, 166-unit, 4-story elevator-serviced asset with interior conditioned corridors located in the heart of the Viera master-planned community, the Space Coast''s most coveted and affluent submarket. The asset was originally developed by RangeWater in 2021 and was part of their Olea brand, which was geared to target an older, more established resident base. As a result of this programming, the Property features a huge amenity footprint as well as a very affluent on-site resident profile.

Azul is centrally located within Viera and is walkable to Health First''s Viera Hospital campus, the new Publix-anchored Addison Center at Viera shopping center, A-rated Quest Elementary School, and less than 5 minutes from Avenue Viera. Easy connectivity to I-95 provides residents with a quick commute to other major Space Coast employment centers including Space X/Blue Origin, L3Harris, Northrop Grumman, and the entire Health First hospital system, all within a 30-minute drive of the property. 

Please let us know if you have any questions or if you would like to schedule a tour of the property.',TRUE,TRUE,''),
('The Milton','6 - Passed','Washington, DC-MD-VA',253,2023,592885,150000000,NULL,'2026-01-27','2026-02-03','Coming Soon - Milton: $150M --- ~5% cap in-place

JS: new deal in national landing area, looks nice but too big and new',FALSE,TRUE,''),
('Solea Wellen Park','6 - Passed','Sarasota-Bradenton, FL',204,2025,259803,53000000,NULL,'2026-01-27','2026-02-03','All Docs Saved - 
 

Pricing guidance for Soléa Wellen Park is $53MM or $260k/unit.

 

A few key bullet points to note:

Brand-new, Class A, 55+ active adult community
Below replacement cost acquisition opportunity
Four-story, elevator serviced, mid-rise product with air-conditioned interior corridors
Located in Wellen Park - one of the top-ranked master planned communities in the U.S.A.
2 future healthcare facilities are being developed within walking distance',TRUE,TRUE,''),
('The Turn Apartments','6 - Passed','Phoenix-Mesa, AZ',166,1999,216867,36000000,NULL,'2025-08-29','2026-02-03','All Docs Saved - $36M',TRUE,TRUE,''),
('Park Estates','6 - Passed','Atlanta, GA',25,1962,100000,2500000,NULL,'2026-01-21','2026-01-23','All Docs Saved 2/3 in portfolio

Ethan,

We are targeting $100-105k/door for these.  All 100% renovated turnkey deals(See OM – New roofs, windows, 100% unit renovations, exterior paint etc).  If you stabilize current in-place rent at 93% occupancy and ~5% bad debt below are the cap rates for each deals.  

Canopy West: 7.25% cap (8.25% cap with $1,200/unit water expense)
Park Estates: 7.25% cap
Rivington: 7.0% cap in-place on T1 (is 94% occupied)  

Canopy has a high than normal water bill due to leaks and the ownership has received bids to replace 100% of the water main supply lines.  Unfortunately, we must wait for warmer weather to replace them.  

See attached bids/info on the water line replacements. (~$100k for all new piping and fixing the parking lot.',TRUE,FALSE,''),
('Canopy West Apartments','6 - Passed','Atlanta, GA',89,1972,101123,9000000,NULL,'2026-01-21','2026-01-23','All Docs Saved 1/3 in portfolio',TRUE,FALSE,''),
('The Rivington EAV Apartments','6 - Passed','Atlanta, GA',16,1962,100000,1600000,NULL,'2026-01-21','2026-01-23','All Docs Saved 3/3 in portfolio
Ethan,

We are targeting $100-105k/door for these.  All 100% renovated turnkey deals(See OM – New roofs, windows, 100% unit renovations, exterior paint etc).  If you stabilize current in-place rent at 93% occupancy and ~5% bad debt below are the cap rates for each deals.  

Canopy West: 7.25% cap (8.25% cap with $1,200/unit water expense)
Park Estates: 7.25% cap
Rivington: 7.0% cap in-place on T1 (is 94% occupied)  

Canopy has a high than normal water bill due to leaks and the ownership has received bids to replace 100% of the water main supply lines.  Unfortunately, we must wait for warmer weather to replace them.  

See attached bids/info on the water line replacements. (~$100k for all new piping and fixing the parking lot.',TRUE,FALSE,''),
('Kasteel at Stone Mountain Apartments','6 - Passed','Atlanta, GA',102,1972,78431,8000000,'2026-01-23','2025-11-20','2026-01-22','All Docs Saved - Ethan- hope you are doing well. Thank you for your interest in Kasteel at Stone Mountain. Interesting basis here with attractive loan assumption. 

Price guidance is $8 Million, $80K+ per unit, or about $85/sf which equates to a ~7*% FY1 Cap.
*Assumes 6% vacancy, 4% concessions, and 6% bad debt loss
 
•	Kasteel at Stone Mountain benefits from an in-place Fannie Mae loan with a favorable 3.81% all-in rate and 8 years of term remaining. 
o	Assumable loan proceeds (~$6.7M) provide attractive leverage.
•	Property revenue can be increased $185k+ through the normalizing of occupancy and collections in-line with neighboring comps.
•	All 102 units are in classic condition and can be brought to a market upgraded scope. Renovation scope inclusive of a washer/dryer, microwave, subway tile backsplash, and stainless-steel appliances.
•	Kasteel at Stone Mountain is located within the Stone Mountain/Tucker industrial corridor and adjacent to the Lithonia industrial node. These markets combine for over 35M SF of industrial space, including a recently delivered 2.7M SF Amazon Fulfillment Center. 

Let us know when you would like to tour.',TRUE,TRUE,''),
('Monterra Apartments','6 - Passed','Phoenix-Mesa, AZ',258,2001,166666,43000000,'2026-01-22','2025-12-03','2026-01-22','All Docs Saved - $43M',TRUE,TRUE,''),
('Mountain Brook','6 - Passed','Nashville, TN',248,1995,191532,47500000,'2026-01-22','2026-01-07','2026-01-22','All Docs Saved - Upper $40MM range on this one. Please let me know when you’re available for a tour or call to discuss.',TRUE,TRUE,''),
('1540 Place Apartments','6 - Passed','Nashville, TN',240,1998,208333,50000000,NULL,'2026-01-21','2026-01-21','All Docs Saved - 

1540 Place, currently operated as student housing, offers investors the opportunity to convert the asset to conventional operations by increasing the unit count from 240 to +/-432 (depending on final unit mix). 
 
By doing so, you would be able to significantly reduce your cost basis and boost the asset’s NOI by taking advantage of Murfreesboro’s strong market rate fundamentals.
 
In light of the 2022–2023 Murfreesboro moratorium and ongoing zoning constraints restricting new multifamily development in Rutherford County, repositioning the existing Student-Housing Operations to Conventional would allow you to capture growing market-rate demand in a structurally supply-constrained market with limited risk. 
 
Additional Summary below:
 
1540 Place | 432 Units* | 1998 Vintage | Murfreesboro, TN 
•	Property Name: 1540 Place | Address: 1540 Lascassas Pike, Murfreesboro, TN 37130
•	Deal Website: https://1540place.sharplaunch.com/
•	CA / Doc Center: https://1540place.sharplaunch.com/signup
•	Unit Count: 240-units | Year Built: 1998 | Market Avg. Rents: ~$1,386
•	Asset Type: Late ‘90s Value-add // Student Conversion 
•	Pricing Guidance: ~$50MM
o	Opportunity via Conversion to Increase Density to ~432-Units 
o	~$3.0 Million (~$12.5K/unit) in Capital Improvements Invested to date 
o	Within 5-Miles of National Retailers and Major Shopping Centers
o	40%+ Population Growth Over the Past 10 Years
?	Murfreesboro Employment Hub: Nissan North America HQ (~8,000 employees), National Healthcare Corporation (~2,500 employees), Amazon Fulfillment Center (~5,000 employees) and more, 1540 Place is centrally located to benefit from Murfreesboro’s growing economy.
 
Let us know once you had a chance to dig in and let’s set up a time to discuss!

Hey guys - great to hear from you.

Looping in the rest of the team for visibility, as well as assistance in providing additional information for you guys!

Guiding to low $50M, which equates to a mid/upper-5% Cap on in-place financials. 

Currently on a plane to NYC but available only cell to text/call on the deal to discuss in greater detail!',FALSE,TRUE,''),
('Burke Shire Commons Apartments','6 - Passed','Washington, DC-MD-VA',360,1986,400000,144000000,NULL,'2025-09-30','2026-01-20','All Docs Saved - Ethan,

Thanks for reaching out. Guidance is mid to high $140’s which is about $400k/unit and 5.25% T3/T12 tax adjusted cap rate. The unit mix is over 64% 2BR + 3BR’s and it’s the only multifamily asset within 3+ miles in any direction and within the coveted Robinson HS district, one of the top Fairfax County schools with A rating (Niche).  A great suburban location with walking distance to Burke VRE Station and Burke Town Center.  100% of units offer a ‘next generation’ value add upside over the 2014 era renovations.',TRUE,FALSE,''),
('The Ellington','6 - Passed','Dallas-Fort Worth, TX',266,1997,274436,73000000,'2026-01-16','2025-12-02','2026-01-16','All Docs Saved- Hey Ethan.  $73M.  Let me know if you would like to set up a tour.',TRUE,TRUE,''),
('The Hathaway at Willow Bend','6 - Passed','Dallas-Fort Worth, TX',229,1986,179039,41000000,'2026-01-16','2025-12-09','2026-01-16','All Docs Saved - $41 million is the strike price.  Let us know if you would like to set up a tour here.',TRUE,TRUE,''),
('The Monroe on Monterey','6 - Passed','Melbourne-Titusville-Palm Bay, FL',271,1985,129151,35000000,'2026-01-14','2025-11-13','2026-01-15','All Docs Saved - Ethan, 
Our pricing guidance is $35M ($129K PU), which is a 6% cap in-place with value-add upside to get you to a 7.10% cap in year 1. We will have materials available early next week.',TRUE,TRUE,''),
('The Cove at Fairforest','6 - Passed','Greenville-Spartanburg-Anderson, SC',152,1978,125000,19000000,'2026-01-14','2025-12-02','2026-01-15','All Docs Saved - Ethan – Hope you had a nice Thanksgiving. Guidance for Cove at Fairforest is $125k-$130k/unit which is a T3, 6.5% tax abated cap rate. Stabilizing occupancy to 95% and bad debt to market levels brings the normalized cap rate to 7.25%+.

Cove at Fairforest arrives to market with a proven value-add on 60 units (39%) that are achieving premiums north of $160, paving the way for new ownership to continue the interior upgrade program and push the post renovation cap rate close to 9%. Over $2.38M has been infused into the asset including major exterior, amenity, and mechanical upgrades. The property is currently in the South Carolina Tax Abatement program which abates 100% of the property taxes if rents are kept below certain AMI thresholds. Rents can still be increased another $210+ while remaining compliant.  

The proximate location south of downtown gives residents direct access to high end retailers (Publix, Starbucks, Haywood Mall), employers (Clemson I-Car, TD Bank, Prisma Health) and top-ranking schooling. The immediate area surrounding Cove at Fairforest is characterized by its strong demographic base with average HHI’s north of $130k and rent growth that is projected to outpace (16% through 2030) other major Carolina’s markets. 

CFO is tentatively set for the first week of January and let us know if you have any questions or would like to schedule a tour.',TRUE,TRUE,''),
('SYNC at West Midtown','6 - Passed','Atlanta, GA',184,2014,211956,39000000,'2026-01-14','2025-11-20','2026-01-15','All Docs Saved - 

Ethan – 

Price guidance is around $40M, or $215k/unit, which is an in-place 5% cap.
 
•	Rare, surface-parked infill asset - off of Collier Road in Upper Westside neighborhood
•	Adjacent to Westside Beltline Connector Trail -- under construction
•	Next door to "Upper West Market" - a 97,000 SF indoor farmers market filled with local vendors set to open in 1Q-26
•	YTD Net Rental Income up 14% while maintaining occupancy with minimal bad debt 
•	Easy VA: install W/D equipment in 117 remaining units (64%)
•	25%-35% below replacement cost 



From Miles: 210 / door, starting below 5, but quickly growing out of it
Unique pocket where rents are much lower than new stuff
You can do value-add but don’t need to (they did not)
Pinler has been buying a lot of the 2010-2015 type of stuff we look at (Carlyle and Crow is their equity)
Right on the silver comet?
Not competing as much with the new stuff so have not gotten hit hard with supply / softness
CFO first week in January',TRUE,TRUE,''),
('Pointe South Townhomes','6 - Passed','Atlanta, GA',160,1998,140000,22400000,'2026-01-13','2025-12-03','2026-01-13','All Docs Saved - 
Hey Ethan,
 
Appreciate you reaching out on this one. Please see below for a high-level summary of the opportunity and guidance: 
 
Pointe South | 160 Units | 1998 Built | 90% Occupied / 93% Leased | Jonesboro, GA
 
•	Link to Financials and CA here: https://multifamily.cushwake.com/Listings/31712 
•	Guidance is +/-$22,400,000 (+/-$140,000/unit) 
o	At guidance, the T6 Income/Yr 1 Pro Forma Tax Adjusted Expenses (~$8500/unit) cap rate is 5.85%
?	Cap Rate at 95% occupancy is +6.50% with current in-place rents
?	November T12 is not yet available but cash collections were $213,356 at 90% Occupancy
o	Underwriting expense notes:
?	T12 insurance is artificially high as part of a larger umbrella policy. We have a stand-alone quote from the owner’s insurance broker in the war room between $700-$800/unit
?	T12 water/sewer expense from Jan-July ’25 was higher than normal due to a water leak. It was found and fixed in the summer. Yr1 water/sewer should be ~$180k/year
?	T12 R&M is high due to $85k of non-reoccurring paint work done in the past year on interiors/exteriors that were not capitalized. 
•	Pointe South is the only 3 BR/2BA Townhome community in South Atlanta both east and west. The highly desirable floorplans are unique amongst its comp set and offer a differentiated product for families that lend to a stickier tenant base 
•	Current ownership is a traditional, local family office who does not renovate or “value-add” their properties. As such, Pointe South is a blank canvas to upgrade interiors and amenities to be more in-line with its competitive set. 3 Bedroom units at any of the comps have in-place rents $220-$350 higher. Average In-Place rents at Pointe South: $1428
o	The Park at Tara Lake (1998 Built, 3.75 miles away) 3 BR rents: $1647 
o	Wynthrope Forest (1999 built, 1.11 miles away) 3 BR rents: $1,714
o	The Reserve at Garden Lake (1990 built, 1.68 miles away) 3 BR rents: $1,774
•	Immediate Opportunity to increase other income through multiple avenues (at 95% Occupancy):
o	Install W/D Appliances and charge $45-$50/month: ~$90k Additional Revenue 
o	Implement Valet Trash: Potential ~$45k+ Additional Revenue 
o	Charge Pet Fees/Pet Rent: Potetential ~$15k additional revenue (assuming 35% of units)
o	Charge for Trash/Pest (property currently does not) which would yield ~$35k/year in additional revenue  
•	Pointe South is in the City of Jonesboro, however it is situated far SW of the city limits along Hwy 85. Demographics at the property and surrounding area are closer to Fayette County’s demos. 
o	Avg HHI 1-mile radius: $69,441 
o	2.55 Miles from Fayette Pavilion (https://www.shopfayettepavilion.com/). 1.6M SF Power Center Renovated in 2023. Tenants include: Belk, Walmart, Target, The Home Depot, Hobby Lobby, Kohl’s, Publix, Bath & Body Works,  Cinemark Tinseltown, Marshalls, Ashley Furniture, etc. 
 
Please let us know if you have any additional questions or would like to tour. The Call for Offers date is currently set for Tuesday, January 13th, however we also encourage preemptive offers if you feel so inclined.',TRUE,TRUE,''),
('Paxton Cool Springs','6 - Passed','Nashville, TN',328,2019,320121,105000000,NULL,'2025-09-03','2026-01-12','All Docs Saved - Hey Ethan – 105/106MM range is guidance.',TRUE,TRUE,''),
('Doria Apartments','6 - Passed','Norfolk-Virginia Beach-Newport News, VA-NC',160,1992,175000,28000000,'2026-01-07','2025-11-20','2026-01-07','All Docs Saved - Hey man – 

Good to hear from you as always. 

This one is unique, are you free to jump on a call to discuss? Easier to explain verbally. 

That said, guidance is $28M. A few high level bullet points to take into consideration. 

-	Current ownership purchased the asset for $33.5M in 2022
-	The seller didn’t have an asset management arm until recently, so they had a tough time taking over the asset, hence why they haven’t been able to successfully execute a business plan. The property is on a better trend, but it could really benefit from a team with asset management oversight 
-	They have done a good job renovating units, but there is still ample upside there. We have the biggest units of any of our competing properties, which has us staying business with continuous qualified traffic. 
-	Admin, marketing and payroll are running incredibly high. We normalized those on look forward which helped contribute to our year 1 cap rate of a 6.75%. 
-	After this last slew of evictions, bad debt should be behind us. We recently increased resident requirements, so the tenants we are accepting are more qualified. 

Again, this is all easier to explain over a call. Let me know if you’re free to discuss!',TRUE,TRUE,''),
('Overby Park Apartments','6 - Passed','Atlanta, GA',76,2002,157894,12000000,NULL,'2025-11-18','2026-01-06','All Docs Saved - Ethan- Hope you are doing well. Significant upside day one here. Would be a great fit for Stonebridge. Let me know if you have any questions or would like to tour.

Guidance is ~$150k+ per unit or $12M.
•	Overby Park is 76-unit oversized townhome deal built in 2002 and still owned by the original developer, representing an untouched value-add opportunity and immense operational upside.
•	Typically occupied at 100%, the property has many long-standing residents (50% from pre-COVID, 16% in-place for 10+ years) and offers the ability to mark rents to market by $150+ to inferior, older garden multifamily product in the immediate vicinity.
•	Strong Pre-Value Going-In Yield: A ~6.0% FY1 tax-adjusted cap rate provides an attractive going-in yield prior to renovation.
•	The property consistently remains 100% leased with T12 vacancy at 1.9%, demonstrating consistent tenant demand and operational stability. The property often operates with a waitlist for new residents.
•	100% of the units are in classic condition. Nearby multifamily comps illustrate headroom of $150 to renovated floor plans.
•	Below Market Rents: Despite the strong operational performance, rents are currently over $150 below market, presenting a clear and immediate opportunity for value creation. Ownership is transparent of their preference to maintain occupancy and not push rents.
•	Day-one value-add opportunity: All units have washer/dryer connections but no physical W/D sets.
•	Meds Employment Base: Surrounded by the leading hospitals in southwest Atlanta with Piedmont Newnan, City of Hope (Cancer Center of America) employing +2,800 with an economic impact of +$2.3B.
•	Surrounded by healthy demographics with 1-mile average incomes of $112k and zoned for A- & B+ schools. Located just 2-miles from the growth center of Downtown Newnan.
•	Long-term residents offer immense rental income upside, residents from pre-covid have in-place rents averaging $1,180, those units today rent for $1,527 on average, a 30% delta.
•	Outstanding price per pound offered at a material discount to multifamily comps that are older and have smaller floor plans.',TRUE,TRUE,''),
('Meridian Obici','6 - Passed','Norfolk-Virginia Beach-Newport News, VA-NC',224,2016,235491,52750000,'2025-12-12','2025-11-05','2025-12-16','All Docs Saved - Hi Ethan, 

Guiding to $52,750,000/235kpu equating to a Year 1 Cap Rate north of 5.75%, great basis play and significant discount to replacement for high-quality, elevator served product in Hampton Roads’ fastest growing city.
Additional deal points below:
•	Tremendous leasing momentum with 60-day leases nearly 9% over current leased rents. The Suffolk Class A Market has averaged 4.60% rent growth over the last 5 years, outpacing the larger Hampton Roads Market with an average rent growth of 3.82% over the last 5 years.
•	In-place rents are 16% below top of market; buyers have flexibility to capitalize on organic rent growth or implement a targeted reno scope to include hard surface countertops, lighting, and appliance package.
•	Proximate to Sentara Obici Hospital, a 175 Bed Hospital that is part of the Sentara network, employing over 30,000 people, the Rt 58 Distribution and Logistics Corridor that spans 508 miles from Virginia Beach, Virginia to Harrogate, Tennessee, and downtown Suffolk which is rapidly becoming one of the most desirable destinations to live in Hampton Roads (35% home price growth and 34% Median Household Income growth over the past 5 years).
•	Desirable demos with one-mile Household Incomes averaging $120k+ and 60% white collard employed.
•	Attractive in-place financing – fully amortizing note originated in Feb 2022 with proceeds totaling $29.679M, 372 months of term at an all-in rate of 4.342%.',TRUE,TRUE,''),
('Axiom','6 - Passed','Washington, DC-MD-VA',272,2020,330882,90000000,NULL,'2024-11-13','2025-12-15','Following up on our off-market MD conversation, see attached Axiom at Cabin Branch OM. We had this out earlier in the year and when we called for offers (last week of June/B&F first week of July) rates ran on us… not to dissimilar to where they are now… the more things change the more they stay the same??
 
That said, we had a seller at $90M, which on a YR1 actual RE taxes is a 5.75% cap and is a YR1 fully tax adjusted 5.50% cap. ZRS would add a ton of value on the management side. Also, there is a lot of room in the rent and no future competing supply. If you think this is interesting happy to send you the current financials.',TRUE,TRUE,''),
('The Towers on Franklin II','6 - Passed','Richmond-Petersburg, VA',128,1964,NULL,NULL,NULL,'2025-10-21','2025-12-11','All Docs Saved',TRUE,TRUE,''),
('The Towers on Franklin I','6 - Passed','Richmond-Petersburg, VA',204,1964,NULL,NULL,NULL,'2025-10-21','2025-12-11','All Docs Saved -',TRUE,TRUE,''),
('Avia 266','6 - Passed','Phoenix-Mesa, AZ',267,1984,205992,55000000,'2025-12-11','2025-11-13','2025-12-11','All Docs Saved- Ethan – guidance is $55M.',TRUE,TRUE,''),
('Riversong Apartments','6 - Passed','Sarasota-Bradenton, FL',179,2015,217877,39000000,'2025-12-10','2025-11-05','2025-12-10','All Docs Saved  - Guidance for RiverSong is $39MM.

 

A few key bullet points of note:

Institutional grade, core-plus asset with proven value-add potential
Irreplaceable waterfront location along the Bradenton Riverwalk
Four-story, concrete block, elevator serviced mid-rise asset with structured parking
Below replacement cost acquisition opportunity
Located less than half a mile to Manatee Memorial Hospital and the Bealls Corporate Headquarters',TRUE,TRUE,''),
('Solamar Apartment Homes Kissimmee','6 - Passed','Orlando, FL',210,2023,257142,54000000,'2025-12-10','2025-11-03','2025-12-10','All Docs Saved 

Ethan and team, 

Great to connect with you on this opportunity!  

Guidance for Solamar Kissimmee is $54M ($257K PU / $228 PSF) which represents a 6% cap rate in year 1. We will have an OM and doc center available by early next week. 

Solamar is a 210-unit new construction build-to-rent townhome community in Kissimmee, Florida. This differentiated townhome product offers the spaciousness and privacy of single-family living within an amenitized rental community. The property features large format 2- and 3-bedroom townhomes with private entries and semi-private backyards, positioned just 10 minutes from Walt Disney World (Orlando''s largest employer with 77,000+ employees) with immediate access to US Highway 192 and I-4. Solamar benefits from exceptional proximity to highly-rated Celebration High School and Valencia College East Campus, plus walkable access to Walmart, ALDI, Chipotle, and Wawa. The community sits within a thriving job market that added over 45,000 positions in 2023, with unemployment at 3.7% versus the national average of 4.2%.

Key investment drivers:
•	Rare Product Type: Build-to-rent represents only 1-3% of multifamily stock with 70-80% tenant retention versus traditional apartments, providing landlord leverage for rent growth
•	Value vs. Ownership: Renting is $1,012/month (48%) more affordable than buying comparable townhomes, with acquisition at up to 30% discount to area for-sale product
•	High-Growth Location: 70% population surge in Osceola County from 2010-2024, driven by proximity to Disney World and emerging NeoCity technology district
•	Income Enhancement Potential: Value-add opportunities through backyard fencing and smart-home packages to boost other income
•	Premium Amenity Package: Resort-style pool, fitness center, pickleball court, clubhouse, and dog park, differentiating from traditional rental options',TRUE,TRUE,''),
('ULake Apartments','6 - Passed','Tampa-St. Petersburg-Clearwater, FL',300,1980,133333,40000000,'2025-12-10','2025-11-13','2025-12-10','All Docs Saved - Thanks for reaching out. Our pricing guidance on ULake Apartments is $40M ($133k per unit). The property is currently operated as student housing with leases signed by the bed; however, only approximately 30% of the units are occupied by students with the majority being rented to tenants working at the abundance of “Meds & Eds” employers in the immediate area.

At our guidance price, the cap rate on in-place numbers is in the low 5%’s, though there is immediate upside potential through implementing an interior value-add strategy and normalizing other income and expenses based on typical market-rate operations. We are projecting a stabilized yield on cost north of 7%+. This is achievable through property/market trends highlighted below:
 
Compelling Operational Upside Potential: 
•	$468,000 annual income increase through operational improvements including RUBS implementation ($75/month pro-forma vs. in-place $20), cable income, valet trash, and reserved parking 
•	Immediate operational expense savings upon conversion from student housing to traditional multifamily operations

Ideal Value-Add Candidate: 
•	1980 vintage, 300 units with 100% of units offering value-add opportunities
•	$720,000 annual revenue increase potential through interior upgrades ($200/unit monthly premium)
•	All units currently feature in-unit washers/dryers and hurricane-grade windows were installed in 2014

Irreplaceable Location Benefits: 
•	Within a 5-minute drive of three major hospitals (Moffitt Cancer Center, AdventHealth Tampa, James A. Haley Veterans'' Hospital) and the University of South Florida (50,000 students, 16,000 employees)
•	Direct access to the $1 billion Rithm at Uptown redevelopment and future 35,000-seat USF Football Stadium (2027 delivery)
•	Less than a 20-minute drive to Downtown Tampa (71,000 employees) and Westshore Business District (104,000 employees)',FALSE,TRUE,''),
('Tower on Piedmont','6 - Passed','Atlanta, GA',155,2009,348387,54000000,'2025-12-10','2025-11-06','2025-12-10','All Docs Saved - 
Some notes here from Miles:
330s / 340s 54M
Extra 200k NOI from t mobile lease
High 4s cap rate without new retail income
Proforma north of 5.25%
Negative press focused on midtown and buckhead
Buckhead now on other side of the trend
Midtown still has some struggles in pockets
Property is performing well
Not a ton of pipeline – last deal was Alta next door, rents are good but smaller units
Big units for location
Some tenants that are waiting to buy homes, doctors, corporate relcoations
150k avg income at property
Send trade out report
October trade outs – 1.8% growth on renewals, and 6% growth on new leases (no concessions)
Towers CFO 12/10 and awarded before Christmas 

Price guidance for this boutique deal is $50M+ or approximately $320k/u. It is available at a basis of half of today’s replacement cost and performing well (GPR up 4% YTD).
 
•	Located at Peachtree & Piedmont intersection in the heart of Buckhead (89 Walk Score)
•	2009 tower originally constructed as a condo building 
•	Oversized floor plans (1,225 SF) appeal to a mature demographic 
•	Current ownership spent $2.75M in the last three years, renovating lobby, corridors, and all amenities 
•	58 units (37%) renovated and capturing $450~ premium
•	Avg. HHI for renovated units is $187,000
•	Adjacent to brand-new Publix and recently revitalized shopping center 
•	1/3 of a mile walk to Buckhead Village (St. Regis, Le Bilboquet, Delbar, etc.)',TRUE,TRUE,''),
('Waterside Towers','6 - Passed','Washington, DC-MD-VA',550,1971,254545,140000000,'2025-12-09','2025-11-03','2025-12-09','All Docs Saved - Thank you! 

Guidance is $140mm --- 6.5% Cap in-place.',TRUE,TRUE,''),
('Novel Nona','6 - Passed','Orlando, FL',260,2023,326923,85000000,'2025-07-15','2025-06-12','2025-12-04','All Docs Saved - Ask on this is in the $330-$340K''s per door range, which is around a 5% on the in-place rent roll with stabilized operation assumptions and year 1 will be 5.25% or better, depending on how you burn down concessions. 

This is the nicest deal in the submarket and will be the only surface parked garden property to offer interior, conditioned corridors. Definitely one worth looking at and spending some time on.

The Nona area continues to thrive from an employment and demographic perspective, with a lot of additional growth coming into the submarket. AdventHealth is well underway on their brand new $400M+ hospital, less than a mile to the north of the property, and UCF and Nemours also continue to expand, which will bring new jobs to the market. Additionally, the property is zoned for all A-rated schools, the average household incomes for on-site residents are nearly $150K and average home values are over $600K, so there is a huge discount for renting vs owning. 

Let us know if you have any questions as you review or if you''d like to schedule a tour.',TRUE,TRUE,''),
('Commons at Town Square','6 - Passed','Washington, DC-MD-VA',116,1971,NULL,NULL,NULL,'2025-11-13','2025-12-04','Rent roll is the same as Waterside Towers, T12 separate.',FALSE,TRUE,''),
('Waterside Townhomes','6 - Passed','Washington, DC-MD-VA',20,1971,NULL,NULL,NULL,'2025-11-13','2025-12-04','Rent roll same as Waterside Towers, T12 separate.',FALSE,TRUE,''),
('Hudson 5401 Phase 1','6 - Passed','Raleigh-Durham-Chapel Hill, NC',192,2019,218750,42000000,NULL,'2025-07-30','2025-12-04','All Docs Saved - Will – Great catching up with you. Look forward to finding a way to work together this year.

As discussed, we are prepping this one for market currently and plan to launch over the next few weeks but know that we owe you one and would like to give you an early look here. 

Please execute the attached CA and see attached for the UW materials for Hudson 5401.  Also see below for an overview of the opportunity and pricing guidance.
 
Hudson 5401 - Google Maps
 
o	Hudson 5401 – Phase I
?	Website: Hudson 5401
?	Address: 7760 Midtown Market Avenue, Raleigh NC 27616
?	Occupancy: 96%
?	Unit Mix (2019 Build | 192 Units)
?	3 -Story, Surface Parked, Garden
?	Market Rent: $1,567 | Effective Rent: $1,463
?	1x1 | 731 AVG SF | $1,392 Effective Rent | 75%
?	2x2 | 1,084 AVG SF | $1,681 Effective Rent | 25%

o	Hudson 5401 – Phase II 
?	Website: Hudson 5401
?	Address: 7760 Midtown Market Avenue, Raleigh NC 27616
?	Occupancy: 91%
?	Unit Mix (2023 Build | 264 Units)
?	3 -Story, Surface Parked, Garden
?	Market Rent: $1,881 | Effective Rent: $1,672
?	1x1 | 793 AVG SF | $1,430 Effective Rent | 36%
?	2x2 | 1,184 AVG SF | $1,750 Effective Rent | 50%
?	3x2 | 1,320 AVG SF | $2,065 Effective Rent | 14%
 
Phase I: Target pricing is $42M or $219K/door.
Phase II: Target pricing is $67.5M or $256K/door.
Combined: Target pricing is $109.5M or $240K/door blended.
 
Both phases represent a high 4% cap rate in-place and a low-mid 5% cap rate YR1. 
 
 Investment Highlights  
 
•	Institutional-Quality Asset: Features upscale interior finishes and a comprehensive package of resort-style amenities, including a dedicated swimming pool for each phase of the development.
•	Walkable Retail Adjacency: Conveniently located next to walkable neighborhood retail, such as Heyday Brewing and Smooth Joe Coffee. Less than 8 minutes from Triangle Town Center and Wake Tech College (+64,000 students).
•	Exceptional Connectivity: Ideally situated at the intersection of US-401 (76,000 vehicles per day) and I-540 (124,000 vehicles per day), offering unmatched access throughout the Triangle region.
•	Attractive Renter Profile: Surrounded by high-income neighborhoods, with average household incomes exceeding $90,000 and nearby home values averaging over $900,000.
•	High-Growth Raleigh Market: The region has experienced 33% population growth since 2010, with 70 new residents moving to the Triangle every day. Named the #1 Best Metro Area for Recent College Graduates by ADP.
•	Robust and Diverse Employment Base: Anchored by major employers including Apple, IBM, Red Hat, WakeMed, Lenovo, and Duke. The market also benefits from proximity to three world-class research universities—UNC, Duke, and NC State.',TRUE,TRUE,''),
('eaves Tysons Corner','6 - Passed','Washington, DC-MD-VA',217,1980,313364,68000000,'2025-12-04','2025-10-13','2025-12-04','All Docs Saved - +/- $68M - 5.7% Cap in-place (T3/T12)

Lots of upside:
•	134 Classic Units 
•	56 Partially Renovated (~$150 above classics) 
•	27 fully renovated units ($300+ above classics)',TRUE,TRUE,''),
('Capitol View on 14th','6 - Passed','Washington, DC-MD-VA',255,2013,462745,118000000,'2025-12-04','2025-10-30','2025-12-04','All Docs Saved - Guidance is $118M which is a blended 5.50% in-place and breaks down to about $108M and $10M, respectively, on the resi and retail. ~$420k/unit on the resi allocation, so 30%+ discount to replacement with restore to core upside through moderate interior unit renovations and common area repositioning. 
 
Below are some key highlights:
-	Exempt from TOPA
-	Supply constrained submarket with no active construction or near-term starts, positioning for near-term outperformance well above third-party projections
-	100% occupied retail anchored by Streets Market since the building’s delivery and features Michelin star-rated restaurant Rooster & Owl along with several other demand driving retailers
o	Rooster & Owl: $1,700+ sales psf | ~3% health ratio
o	95% of the retail space has been in place for at least 6 years 
-	Walking distance to over five million square feet of exceptional retail & entertainment options including Le Diplomate, Barcelona, Mi Vida, and more. Importantly, the building is located a couple blocks from the epicenter of 14th & U… close to it all with the ability to separate to a quieter living environment
-	Transit/commuter-oriented location – short walk to U-Street Metro

Let me know if you want to discuss in more detail. 

Thanks',TRUE,TRUE,''),
('Hudson 5401 Phase 2','6 - Passed','Raleigh-Durham-Chapel Hill, NC',264,2023,255681,67500000,NULL,'2025-07-30','2025-12-04','All Docs Saved - Will – Great catching up with you. Look forward to finding a way to work together this year.

As discussed, we are prepping this one for market currently and plan to launch over the next few weeks but know that we owe you one and would like to give you an early look here. 

Please execute the attached CA and see attached for the UW materials for Hudson 5401.  Also see below for an overview of the opportunity and pricing guidance.
 
Hudson 5401 - Google Maps
 
o	Hudson 5401 – Phase I
?	Website: Hudson 5401
?	Address: 7760 Midtown Market Avenue, Raleigh NC 27616
?	Occupancy: 96%
?	Unit Mix (2019 Build | 192 Units)
?	3 -Story, Surface Parked, Garden
?	Market Rent: $1,567 | Effective Rent: $1,463
?	1x1 | 731 AVG SF | $1,392 Effective Rent | 75%
?	2x2 | 1,084 AVG SF | $1,681 Effective Rent | 25%

o	Hudson 5401 – Phase II 
?	Website: Hudson 5401
?	Address: 7760 Midtown Market Avenue, Raleigh NC 27616
?	Occupancy: 91%
?	Unit Mix (2023 Build | 264 Units)
?	3 -Story, Surface Parked, Garden
?	Market Rent: $1,881 | Effective Rent: $1,672
?	1x1 | 793 AVG SF | $1,430 Effective Rent | 36%
?	2x2 | 1,184 AVG SF | $1,750 Effective Rent | 50%
?	3x2 | 1,320 AVG SF | $2,065 Effective Rent | 14%
 
Phase I: Target pricing is $42M or $219K/door.
Phase II: Target pricing is $67.5M or $256K/door.
Combined: Target pricing is $109.5M or $240K/door blended.
 
Both phases represent a high 4% cap rate in-place and a low-mid 5% cap rate YR1. 
 
 Investment Highlights  
 
•	Institutional-Quality Asset: Features upscale interior finishes and a comprehensive package of resort-style amenities, including a dedicated swimming pool for each phase of the development.
•	Walkable Retail Adjacency: Conveniently located next to walkable neighborhood retail, such as Heyday Brewing and Smooth Joe Coffee. Less than 8 minutes from Triangle Town Center and Wake Tech College (+64,000 students).
•	Exceptional Connectivity: Ideally situated at the intersection of US-401 (76,000 vehicles per day) and I-540 (124,000 vehicles per day), offering unmatched access throughout the Triangle region.
•	Attractive Renter Profile: Surrounded by high-income neighborhoods, with average household incomes exceeding $90,000 and nearby home values averaging over $900,000.
•	High-Growth Raleigh Market: The region has experienced 33% population growth since 2010, with 70 new residents moving to the Triangle every day. Named the #1 Best Metro Area for Recent College Graduates by ADP.
•	Robust and Diverse Employment Base: Anchored by major employers including Apple, IBM, Red Hat, WakeMed, Lenovo, and Duke. The market also benefits from proximity to three world-class research universities—UNC, Duke, and NC State.',TRUE,TRUE,''),
('Bella Lago','6 - Passed','Orlando, FL',156,1988,134615,21000000,'2025-12-03','2025-10-30','2025-12-03','All Docs Saved - 
Hi Ethan, 
The whisper price is $21M which is a 6% cap on the T3 income with T12 expense, assuming an 80% tax adjustment. This two-story garden community offers a new investor the ability to own a solid community in Central Florida that provides quality, work force housing for the residents. The property is all two-bedroom units, which is ideal for families.

In 2015, the current owner completed a $4M full renovation of the community that included major green upgrades including flooring, doors, light and wall fixtures, and appliances. The property was awarded the Florida Water Star Community Gold level standard due to their implementation of these energy efficient appliances and systems.

Bella Lago is situated near Orlando’s major theme parks including Universal, Walt Disney World, and Seaworld, which together boast over 107,000 jobs. Universal Orlando is located a short 15-minute drive from the community and boasts 26,800+ employees throughout their four theme parks and 11 hotels.

Please contact us with any questions or if you want to set up a tour.',TRUE,TRUE,''),
('The Beacon at Seminole Lakes','6 - Passed','Orlando, FL',124,1973,145161,18000000,'2025-12-03','2025-10-29','2025-12-03','All Docs Saved - Case Study for Older Vintage Deals

Ethan, 
Good to hear from you on this one! 
Guidance on Beacon at Seminole Lakes is $18M+ ($145K PU / $164 PSF) which equates to roughly an 6% in-place cap rate. 
This is a compelling value-add opportunity with 100% classic units positioned for interior renovations, with rental premiums up to $250 per unit achievable through capital improvements. The 124-unit boutique garden-style community, features one and two-story construction with 1, 2, and 3-bedroom apartments plus villas averaging 885 square feet with direct walk-up access.
The Beacon sits within minutes of four of Orlando''s largest office submarkets, including Maitland Center (7.5MM SF) less than 5 minutes away and Orlando CBD (95,000+ jobs) just 6 miles from the property. The community is right down the street from AdventHealth''s corporate headquarters and provides direct access to major employers including Charles Schwab & ADP within a 5 minute drive.
Investment highlights include:
•	Value-Add Potential with 100% Classic Units: Substantial renovation potential across all units with premiums up to $250 per unit through quartz countertops, LVP flooring, and washer/dryer additions.
•	Boutique Garden-Style Asset: Low-density setting with resort-style amenities and mature landscaping providing strong repositioning foundation.
•	Supply-Constrained Submarket: Only 4 properties delivered in last 5 years with just one property under construction (delivery Dec 2027), creating 3+ years of limited competition.
•	Exceptional Employment Access: Direct connectivity to 100,000+ jobs across four major office submarkets within minutes of the property.
•	Orlando''s #1 Employment Growth Market: Fastest-growing employment market among 30 most populous U.S. regions, adding 37,500 jobs in 2024 with population growth of 43,500 annually.
Please let us know if you would like to set up a call to discuss further.',TRUE,TRUE,''),
('Summit West','6 - Passed','Tampa-St. Petersburg-Clearwater, FL',266,1972,165413,44000000,'2025-12-03','2025-10-27','2025-12-03','All Docs Saved - High 160k/unit',TRUE,TRUE,''),
('Overture Crabtree','6 - Passed','Raleigh-Durham-Chapel Hill, NC',203,2017,330049,67000000,'2025-12-02','2025-10-24','2025-12-03','All Docs Saved - Greystar/Carlyle

60M on Centennial
$67M on Crabtree',TRUE,TRUE,''),
('Overture Centennial','6 - Passed','Raleigh-Durham-Chapel Hill, NC',188,2020,319148,60000000,'2025-12-02','2025-10-24','2025-12-03','All Docs Saved - Greystar/Carlyle

60M on Centennial
$67M on Crabtree',TRUE,TRUE,''),
('Founders Yard','6 - Passed','Charleston-North Charleston, SC',341,2024,287390,98000000,'2025-12-02','2025-10-28','2025-12-03','All Docs Saved - Hey Ethan - $98M here. Copying Cody in case you have questions.',TRUE,TRUE,''),
('Station 40','6 - Passed','Nashville, TN',246,2016,235772,58000000,NULL,'2025-11-19','2025-11-21','All Docs Saved -- Guidance at $235 a unit. 

Notes from the Broker: 
- Attractive Basis – Station 40 will trade in the high $230,000s to low $240,000s per unit range which, as you guys know better than anyone, is a discount of roughly $100,000 per unit compared to today’s replacement cost. This discount reflects a temporary imbalance in supply fundamentals, which we anticipate will resolve as the market reaches equilibrium within the first year of ownership.
- Market Stabilization – Nashville has consistently ranked among the nation’s most resilient multifamily markets and continues to deliver historically strong absorption levels.  Based on our internal research and supported by other data providers, we expect the market to soon return to equilibrium, followed by little to no new supply.  That paves the way for reduction of concessions, higher occupancy and positive rent growth.
- Value-Add Opportunity – The recent influx of new supply has resulted in substantially higher rents in the West Nashville submarket. The next owner of Station 40 is ideally positioned to capitalize on this elevated rent ceiling and pursue a value-add strategy for unit interiors and amenities to enhance investment returns. The current owner has already renovated 88 units with light upgrades, achieving rent premiums of $150–$250 per month.
- Maturing Submarket – While West Nashville has long provided access to the city’s most affluent neighborhoods, only recently has the immediate area surrounding Station 40 developed neighborhood-scale amenities. These new dining, shopping, office, and entertainment options further enhance the appeal for residents.
Reasonable Underwriting – The pro forma assumptions outlined in the OM are conservative, restricting rent growth to third-party projections, and projecting near-term, leverage-positive cash flows.',TRUE,TRUE,''),
('Pencil Factory Flats','6 - Passed','Atlanta, GA',188,2010,228723,43000000,'2025-11-20','2025-11-03','2025-11-20','All Docs Saved - Coming Soon - Ethan,

There’s a great distress story here. The strike price on Pencil is $43M, or roughly $185K/unit for the multi and $8M ($230 psf) for the retail. Seller would like to run a condensed marketing process and is open to preempts. Good story here for discount to replacement cost for wrap product and upside in rents (currently $1.50 psf) and upside in retail occupancy (recent retail leasing activity has been robust). 

Happy to discuss live and/or meet on-site at your convenience.',TRUE,TRUE,''),
('Outlook Gwinnett','6 - Passed','Atlanta, GA',180,2022,222222,40000000,'2025-11-20','2025-10-28','2025-11-20','All Docs Saved 55+ - Ethan, 

Guidance on Outlook is ~$220K/unit. This is a stabilized asset that’s integrated within the Exchange at Gwinnett shopping district (~500K SF of shops/restaurants – TopGolf, Andretti’s, Sprouts etc). If you consider the strong on-site demographics (18% rent:income), approachable rents (~$1,900) and discount to replacement cost, there’s a compelling investment thesis. I’ll note we just sold the conventional asset next door for $310K/unit. 

We’d be happy to discuss in more detail at your convenience.',TRUE,TRUE,''),
('Alante at the Islands','6 - Passed','Phoenix-Mesa, AZ',320,1996,275000,88000000,'2025-11-20','2025-10-28','2025-11-20','All Docs Saved - $275k per unit.',TRUE,FALSE,''),
('Yardly Paradisi','6 - Passed','Phoenix-Mesa, AZ',193,2024,274611,53000000,NULL,'2025-07-21','2025-11-19','All Docs Saved -  Hi Ethan,
 
Please see below and let me know if you have any questions. 
 
Thank you for your interest in Yardly Paradisi, a 193-home, Build-to-Rent community built by Taylor Morrison, one of the nation''s most trusted home builders (CA: RCM Deal Room Link). Yardly Paradisi is a stabilized, Class-A product located in one of the fastest-growing regions in the nation. More details on the offering below:
•	Guidance: $53,000,000 (±$274,611/unit)
•	Tours: Please reach out to Emily Soto to schedule onsite tours
•	Financing: Please reach out to Brandon Harrington and Bryan Mummaw to discuss new financing options 
•	Call for Offers: August 12th
 
Deal Highlights:
•	Premier Class-A BTR Asset Below Replacement Cost
Built in 2024 by Taylor Morrison, Yardly Paradisi offers a rare opportunity to acquire a best-in-class, newly constructed 193-unit Build-to-Rent community below replacement cost (~$325K/unit).
•	Explosive Submarket Growth in Surprise, AZ
Located in one of the Phoenix MSA’s fastest-growing cities, Surprise has experienced a 12% population increase since 2020 and is projected to exceed 230,000 residents by 2030.
•	Exceptional Rent & NOI Upside
Units are currently renting up to ~$80 below comparable properties, with zero concessions on renewals. Concessions have meaningfully declined, positioning the property for strong organic NOI growth in 2025.
•	Strong Lease Roll-Over Upside
Significant near-term value creation by renewing expiring leases at full market rents without concessions—capturing immediate upside as below-market leases naturally turn over.
•	BTR Outperformance
Build-to-Rent assets command a 21% rent premium over conventional multifamily in Phoenix, driven by high demand for single-family-style living with institutional management.
•	Strategic Loop 303 Location
Directly off Loop 303 in one of the country’s largest Class-A industrial corridors, Yardly Paradisi is surrounded by 171M+ SF of industrial space and 25M+ SF under construction, supporting over 80,000 jobs.
•	Proximity to Major Developments
Just one mile from the ±1.4M SF Village at Prasada retail center (85+ tenants, 2,500 new jobs), with expansion underway; also within reach of the P83 entertainment district and upcoming TSMC facility.
•	TSMC Drives Regional Economic Expansion
Arizona’s largest-ever foreign investment—TSMC’s $165 billion semiconductor mega facility—directly off Loop 303 is generating current economic output of ~$200 billion, employing ~3,000 today and expected to exceed 10,000 upon completion.
•	Best-in-Class Product & Lifestyle
Thoughtfully integrated into Taylor Morrison’s master-planned Paradisi community, the property features 10’ ceilings, smart home technology, private backyards, and lush resort-style amenities including a fitness center, pool, and dog park.
•	Robust Ancillary Income
Strong ancillary income streams include technology packages ($125/unit/month), valet trash ($25/unit/month), pet fees ($40/pet/month with a $350 non-refundable pet fee), amenity charges ($12/unit/month), pest control ($3/unit/month), and 56 detached garages available for lease ($165/garage/month).
•	Phoenix Multifamily Market Momentum
The Phoenix market saw record net absorption of 15,600 units in 2024, while construction starts have slowed—creating a favorable supply-demand dynamic for stabilized assets.
 
Economic Drivers (within 5-25 minute commute):
•	Village at Prasada
•	Prasada North
•	P83 Entertainment District
•	Taiwan Semiconductor Manufacturing Chip Facilities (TSMC)
•	Arrowhead Town Center
•	Surprise City Center
•	Ottawa University
•	Westgate Entertainment District
•	State Farm Stadium
•	Top Golf
•	VIA Resort
•	District at Sportsman Park
•	Park Aldea
•	Amkor Technologies
•	Park 303
•	The Base
•	Reems Ranch 303
•	Luke Logistics Park',TRUE,TRUE,''),
('Mosaic at Metro Apartments','6 - Passed','Washington, DC-MD-VA',262,2008,244274,64000000,'2025-11-19','2025-10-13','2025-11-19','All Docs Saved - Pricing for Mosaic at Metro is around $64M, which is a 6.25% cap on T-12 financials. The property generates an 11%+ cash-on-cash and is not subject to any rent restrictions.

Let’s find a time to discuss in detail.',TRUE,FALSE,''),
('Spectra','6 - Passed','Fort Myers-Cape Coral, FL',324,2017,246913,80000000,'2025-11-19','2025-10-21','2025-11-19','All Docs Saved 


$80M - 246k/door
Coastal Ridge has owned for 7 yrs
developed by stock
Bulk Contract expires 2028, renagotiate
carpet in bedrooms, smart thermostats, fenced in yards, 

Supply story - The Riley is 24% Leased
Alumina? farther away is almost hitting stabilization',TRUE,TRUE,'')
ON CONFLICT (name) DO NOTHING;

INSERT INTO deals (name,status,market,units,year_built,price_per_unit,purchase_price,bid_due_date,added,modified,comments,flagged,hot,broker) VALUES
('The Crossing at Palm Aire','6 - Passed','Sarasota-Bradenton, FL',315,2023,269841,85000000,'2025-11-19','2025-10-22','2025-11-19','All Docs Saved - Hey Ethan, 

Our guidance is $85M ($270K per door). Lease-up has stalled around 75% due to management turnover and broader market softness. That said, this creates a strong opportunity to acquire below replacement cost in an infill Sarasota location. There are only two other assets under construction west of I-75, and performance should improve as management stabilizes and the market matures.

Happy to discuss these details further at your convenience.',TRUE,FALSE,''),
('Gladwen Wendell Falls','6 - Passed','Raleigh-Durham-Chapel Hill, NC',365,2024,263013,96000000,'2025-11-18','2025-11-05','2025-11-18','All Docs Saved - 265k per door – 5 cap. 7% growth on renewals – lets discuss. Are you guys free on Friday or Monday?',TRUE,TRUE,''),
('Waterview at Coconut Creek','6 - Passed','Fort Lauderdale-Hollywood, FL',192,1987,304687,58500000,NULL,'2025-11-07','2025-11-18','All Docs Saved - Target pricing is $305,000 per unit, 5.25 cap.  The submarket continues to perform really well. The product type here is unique because of the high percentage of two-story townhome style unit units.  There is the ability to build an additional  8 units on the site.    

Let me know if you would like to arrange a tour or call to discuss.',TRUE,TRUE,''),
('Waterview At Coconut Creek Apartments','6 - Passed','Fort Lauderdale-Hollywood, FL',192,1987,304687,58500000,'2025-11-13','2024-09-13','2025-11-18','All Docs Saved - Back on market from last yr around this time 

2025 = Target pricing is $305,000 per unit, 5.25 cap.  The submarket continues to perform really well. The product type here is unique because of the high percentage of two-story townhome style unit units.  There is the ability to build an additional  8 units on the site.    

Let me know if you would like to arrange a tour or call to discuss.  


From 2024
“Target pricing is $59mm / 305,000 per unit, going in T1 5.5 cap. The seller carries pretty low insurance so probably at 5.25 cap adjusted.  Still has an opportunity to fully renovate 30% of the property and add in private yards to 50 units.  There’s also an opportunity to add an additional eight townhome units by right.  Let me know if you’d like to arrange a call to discuss or set up a tour.” - Hampton Beebe at Newmark',TRUE,TRUE,''),
('Owings Park Apartments','6 - Passed','Baltimore, MD',174,2002,270114,47000000,'2025-11-17','2025-10-07','2025-11-17','All Docs Saved - Seller is ppl who bought Poplar Glen

47M',TRUE,TRUE,''),
('Elliot Roswell Apartments','6 - Passed','Atlanta, GA',312,1973,176282,55000000,'2025-11-17','2025-10-16','2025-11-17','All Docs Saved - More just to track and see what kindve cap rate this is 

Hello Ethan, 

Price guidance is Mid $50 million or about $150/sf which equates to a 6.0% stabilized cap rate. 
 
Elliot Roswell presents a rare opportunity to purchase a value-add garden community in the highly desirable Roswell/Alpharetta corridor that has seen only 8 trades over the past 5 years. Some of the key investment highlights are, 
 
•	Ideal Unit Mix and Top-Rated Schools - 85% of the property consists of 2-, 3-, and 4-bedroom floorplans (1,200 SF average), including 54 (17%) townhomes
•	47% of Units are Primed for Value-Add - 165 units (53%) have been fully upgraded achieving $150+/unit premiums
•	Excellent Property Level Demographics  - $87k average resident household income (4.5x income-to-rent ratio); top 25 priciest zip code ($625k average home value)
•	Scarcity of Multifamily Deliveries - only four properties (less than 1,000 units) have been built in the City of Roswell over the past ten years, with currently no units under construction or planned 
 
Let us know when you would like to tour.',TRUE,TRUE,''),
('The Preserve At Tampa Palms Apartments','6 - Passed','Tampa-St. Petersburg-Clearwater, FL',378,2002,222222,84000000,'2025-11-13','2025-10-21','2025-11-13','All Docs Saved

$84MM $220k/unit
Inland has owned for 7 yrs 
Mid 5.5 Cap
Bulk Cable day 1
Charge a flat fee for utl, switch',TRUE,TRUE,''),
('Heritage Place','6 - Passed','Nashville, TN',105,1982,219047,23000000,'2025-11-13','2025-10-29','2025-11-13','All Docs Saved - Hi Ethan,

Pricing guidance here is $23m.',TRUE,TRUE,''),
('Rio Hill Apartments','6 - Passed','Charlottesville, VA',139,1995,179856,25000000,'2025-11-13','2025-10-16','2025-11-13','All Docs Saved - 
Ethan - Thank you for reaching out! Below is the rundown on Rio Hill. Let me know if you want to hop on a call to discuss further. 

Guidance: $25M or $180k/unit?.  This is a phenomenal mark-to-market expiring tax credit opportunity. 
 
Overview: 
Doc Center with OM, DD items etc:?Deal Room 
 
Property: 
•	Built in 1995 and consists of 139 units? 
•	?Avg. Unit Size: 1,152 SF 
•	In-Place Rents: $1,471? 
•	LIHTC restrictions expiring Year-End 2025
o	20% at 50% AMI, 80% at 60% AMI
o	Year Place in Service: 1995
o	End of Initial Compliance December 2010
o	End of LIHTC Restrictions December 2025 
Upside: 
•	Current in-place rents of $1,471 remain approximately?$159?per unit (-9.8%) below the 2025 max net rents and?$328?per unit below the projected 2026 max net rent.? 
•	Value Add Opportunity 
•	?Current Ownership Unit Upgrades:
o	37 units with new kitchens & bathroom cabinets
o	25 units with new windows and patio sliders
o	99 units with new durable vinyl plank flooring
o	119 Units - upgraded with Rinnai tankless water heaters 
•	Rio Hill is currently trailing the market rate properties by $200 -$500 despite offering larger average unit sizes than most. This creates clear evidence to continue ownerships renovations that support?$350+ premiums on 2BRs and $500+ on 3BRs  

Comps 
•	We sold Abbington Crossing, a 1979 vintage 493-unit property located .6 miles away, for $211k/unit with average rents at $1,648 at time of sale.  This older vintage property’s rents for 2 and 3 bdrm are $240 and $332 higher than our in-place here which strongly supports our repositioning thesis  
•	The adjacent phase II of Rio Hill, Mallside Forest which is also affordable built in 1998 but with smaller units, has rents for 2 and 3 bdrm units at $202 and $310 higher  
•	The other adjacent property, Arden Place built in 2011, has rents that are $494 and $1,191 for 2 and 3 bdrm units 
 
Location:? 
•	Positioned along Route 29, Rio Hill benefits from direct access to the University of Virginia, UVA Health System, Sentara Martha Jefferson Hospital, DIA Rivanna Station, and Charlottesville’s premier retail and lifestyle destinations.? 
•	Located in a high-income corridor of Albemarle County, with average household incomes of $139,000 within three miles. Recent home sales averaged $607,000, creating a pronounced affordability gap: estimated monthly mortgage payments of $3,728 vs. Rio Hill’s average rents of $1,471 – a $2,200+ monthly savings for residents.? 
•	Global BioPharma giant AstraZeneca is investing $4.5B to expand its manufacturing plants in Albemarle County, creating 1000+ new jobs 





Here is how the 3 yr expiration period works:

-	Starting 1/1/26 you can charge market rent on any vacant units
-	The renewals are restricted for 3 years:
o	You still can only charge the max allowed amount
o	However, many of these units are ~$300 below the max allowed amount
?	So you can bring people up to the max allowed amount (which you could have also done prior to 2026)
?	The difference now is that you have more leverage as if they leave you can now charge market',TRUE,FALSE,''),
('Albion at Murfreesboro','6 - Passed','Nashville, TN',360,2006,208333,75000000,'2025-11-12','2025-10-20','2025-11-12','All Docs Saved - Ethan, before diving into pricing guidance, here are a few key highlights:

•	2006 Construction ? 2024 Conversion: Effectively a new property following comprehensive student-to-conventional and renovation programs:
o	$1M invested in common area and amenity refresh
o	$1.8M in exterior, deferred maintenance, and curb appeal improvements
o	$7–8M (˜$22K/unit) in interior renovations completed
o	Converted all 4BR units into 108 new studios, 1BR, & 2 BR
•	Powerful Post-Renovation Performance: Rents have grown 18% YTD, with $190/unit renovation premiums achieved
•	Outstanding Basis: Provides downside protection relative to replacement cost
•	Runway to Higher Rent Growth:  Minimal new supply due to Murfreesboro’s ongoing MF moratorium — CoStar projects 3–5% rent growth in 2026
•	Sustained Submarket Growth: Adjacent to MTSU with $2B of committed improvements and nearby Barrett Firearms $78M expansion, adding 183 jobs

We’re targeting mid-$70 million sale price, which is a stabilized mid-5% cap rate on September financials (stabilizing concessions and vacancy since it was a construction project until recently).  That is a high-5% to 6% cap on Year 1.  The property is 89% leased today and projected to be 90+% before close.

One thing to keep in mind is that Albion Murfreesboro just completed its student-to-conventional conversion this year. The project was way behind in 2024 due to construction delays, so to accelerate lease-up for the spring leasing season and the 2025 school year, Albion offered aggressive renewal concessions in late 2024 and Jan 2025.  Those concessions weren’t booked until August and September of 2025, when the resident actually moved in.  So, while it looks like they are offering huge concessions last month most of that is from 9-10 months ago and will burn off in a couple of months.

We don’t yet have a call for offers, but hopefully soon.  Let us know if you have questions or when you can come tour.',TRUE,TRUE,''),
('Bridgeyard','6 - Passed','Washington, DC-MD-VA',530,1950,237735,126000000,'2025-11-12','2025-10-30','2025-11-12','All Docs Saved - $126 mm - $240 K per unit - 5.25% in place cap rate.',TRUE,TRUE,''),
('City Limits Spring Hill Apartments TN','6 - Passed','',254,2023,248031,63000000,'2025-11-11','2025-01-27','2025-11-11','All Docs Saved -
Ethan,
Thank you for reaching out on City Limits.  City Limits, is a 254-unit,  2023-built, 3-story walk up Class A multifamily community built in one of the fastest growing corridors in the Nashville MSA – Spring Hill/Columbia, TN. Featuring large unit sizes (1,200sf) with one of the best amenity packages in the submarket, City Limits shows great.  This deal was originally launched at NMHC this year.  We had a great process and ultimately put the property under agreement. Heavy supply pressures put a strain on property operations during the final stages of lease up and, ultimately, our buyer chose not to move forward. At that point, our client chose to suspend the marketing of the asset until operations more stabilized. 
 
Today, operations have settled in within the backdrop of a submarket reaching stabilization on a historic pipeline of lease up deals. Additionally, this dramatic growth in the area has forced the two municipalities of Spring Hill and Columbia to enact a sewer moratorium on future development.  This step is transforming this submarket from a high growth to a high barrier corridor that will result in higher home prices / higher rental rates.
 
Guidance is $63mm At this pricing in place/tax adjusted yield is 4.7% on economic vacancy of 21% representing substantial upside for Yr 1 buyer underwriting. We have not set a CFO date but expect it to fall in early November. 
 
Please reach out with questions or to set up a tour.  Thanks.



 Was on the market start of 2025
built by old missippi guy
Franklin alpharetta of nashville
300 CA''s
15 offers, 2 REITS
several private funds and 1 family office

5% lower, middish 60''s

 Jay,
I''ll be running point on this opportunity.  Thank you for your interest in City Limits, a newly constructed suburban Class A multifamily asset in the Spring Hill/Columbia corridor of Nashville.  Guidance for City Limits - $66mm ($260,000/unit) - represents an attractive discount to current replacement cost and a mid 5% stabilized yield providing an investor with a clear path to accretive levered returns in the near term.  

The story of City Limits is squarely focused on a story of growth.  The Spring Hill/Columbia area is projected to grow faster than any other area in one of the fastest growing markets in the county.  This growth is rooted in the lowest unemployment in the region and the highest population growth driven by affordability and access to high paying jobs.  

The buyer of City Limits will benefit from a recovery story of elevated supply that is quickly turning to market stabilization. What remains a constant in the area is the increasing cost of housing in the adjacent communities just to its north.  The I-65 corridor remains one of the most attractive demographic stories in the Nashville MSA and the given the lack of future deliveries in the area, robust rent growth is projected to return quickly. 

Please reach out to schedule a tour.  A CFO date has not been set but will be in early March. 

Please reach out with any questions to myself and/or @Cox, Bryan.',TRUE,TRUE,''),
('The Preserve at Lakeland Hills Apartments','6 - Passed','Lakeland-Winter Haven, FL',432,2000,175925,76000000,'2025-11-11','2025-10-20','2025-11-11','All Docs Saved - Ethan,

Initial pricing guidance is $76M, a phenomenal basis at $176K/unit, $167/SF.  

The T3 tax adjusted cap rate is a 5.15% with 17% economic vacancy which trends to a 5.7% cap at 10% economic vacancy and a 6% cap at a normalized 7% economic vacancy.  Current occupancy is 94% with a nice window of fewer than 30 expiring leases through next May.  50% of the value-add remains with ownership currently achieving $152 in rent premiums.  

Situated between I-4 and SR-33 at the midpoint of Tampa and Orlando, the asset enjoys premier connectivity to both metros while anchored by Lakeland’s diversified economy including 23M SF of industrial (and counting), five colleges, 1,200+ hospital beds, and 4M SF of office, including Publix’s newly developed IT campus.  Fantastic play on Lakeland''s continued growth and muted MF supply.',TRUE,TRUE,''),
('Verandahs of Brighton Bay','6 - Passed','Tampa-St. Petersburg-Clearwater, FL',381,2002,299212,114000000,'2025-11-11','2025-10-15','2025-11-11','All Docs Saved - Hi Ethan,

Pricing guidance for Verandahs at Brighton Bay is $300,000 per unit, which underwrites to a 5.25% pro forma cap rate. For reference, this pricing comps to Madison Gateway (1999 vintage), which is selling for approximately $309,000 per unit, and Provenza (2014 vintage) which is closing in 2 weeks also over $300,000 per unit. Newer product in Pinellas County has priced even higher, with deals such as Camden Clearwater trading for $385,000 per unit and Windsor Clearwater at $320,000 per unit. 

A few important highlights to note:

-	Excellent Location:  The asset is in Gateway, the largest job market in Tampa and home to several Fortune 500 companies. It’s at the base of both the Gandy and Howard Frankland bridges allowing for a 15-minute commute to South Tampa and the Westshore Business District (largest office market in Tampa).  The immediate neighborhood offers access to waterfront dining, boating and nature preserves, while downtown St. Pete and the 4th Street retail corridor are a short drive away. Just across Gandy Blvd from the property, the Derby Lane property is in the early stages of planning for redevelopment. The 136-acre site has the potential to be redeveloped into a large-scale mixed-use district like Hyde Park Village in Tampa, and it has come up for consideration as a site for new Tampa Bay Rays stadium.
  
-	Strong Submarket Fundamentals:  Demand for rentals in the Gateway submarket is very strong, while new supply has been limited. As a result, occupancy levels are healthy, rents have been increasing, and what little new supply that has delivered has leased up rapidly.
   
-	Value Proposition:  Verandahs is a very attractive, well-maintained community with many of the same features as the new supply in the area (9’ ceilings, expansive amenities, open floor plans, etc.), while renting at a significant discount to newer product in the area. With its enviable location and high-quality, Verandahs is well positioned to draft off the newer products’ higher rents.
   
-	Proven Value-Add: As noted in the teaser, 65% of the units have been “fully” renovated, leaving the opportunity to upgrade 35% of the units. Additional opportunities to add value include adding smart home features, rolling out bulk wifi, and updating some of the amenity spaces.   

We will call for offers the week of November 17th. We would be happy to set up a tour, or we can have a call to discuss further.',TRUE,TRUE,''),
('Aria At Millenia Apartments','6 - Passed','Orlando, FL',270,2017,251851,68000000,'2025-11-06','2025-10-09','2025-11-10','All Docs Saved Ethan,

Guidance on Aria at Millenia is $68M, $250K per door, which is a low 5% trailing, tax-adjusted cap rate, and a high 5% to a 6% Yr. 1 with the continued rollout of the operational enhancements discussed below.

The Property was originally developed by Lennar in 2017 featuring one of the largest amenity footprints in the submarket and well-appointed unit interiors featuring quartz and granite counters, crown molding, subway tile backsplash, stainless-steel appliances, and vinyl-plank flooring in the living rooms and wet areas. Property performance has been strong, with little to no concessions since the spring and positive recent leasing trade outs on new leases and renewals.

Additionally, current ownership recently implemented additional revenue-generating services with a newly signed bulk Wi-Fi contract that is in the process of being rolled out, Fetch package service, and increased trash and common area rebill charges. New ownership will have the opportunity to continue phasing in these added services as well as perform light value-add enhancements including the addition of plank flooring in the bedrooms, framed bathroom mirrors, implementing a smart home technology package, and more.

Aria is located within the heart of the Millenia retail corridor (2.5M+ SF) and less than 15 minutes from Lockheed Martin''s campus, the newly opened Epic Universe theme park, and 3 major hospital systems. Residents also benefit from convenient accessibility throughout the Orlando MSA via nearby Interstate 4 and Florida''s Turnpike, as well as a high barrier-to-entry location with no future garden product planned or under construction in the submarket.

Let us know what questions you have as you review or if you would like to schedule a tour of the property.',TRUE,TRUE,''),
('Crescent at Chevy Chase','6 - Passed','Washington, DC-MD-VA',111,2024,450450,50000000,'2025-11-06','2025-09-29','2025-11-10','All Docs Saved  - Ethan,
 
We are targeting $50m for the deal which is a 6.0% cap rate on proforma with phased in taxes.  The property still has the benefit of a tax abatement which adds some additional cash flow and value.  The property is right at the entrance to the Purple Line on Connecticut Avenue and that is looking to open in about 18 months.  Let me know if you have any questions or would like to setup a call to discuss.
 
Also, I thought you guys would a good candidate for another deal that we have in the market in DC called The V at Georgia Avenue.  The property is REO and we are targeting $325k per unit.  It’s on the smaller side but I’ve got a market seller and the fit out is great.  Here is the link to the deal room - https://multifamily.cushwake.com/Listings/31676.
 
Let me know if there is interest in either of these opportunities.  I hope all is well.',TRUE,TRUE,''),
('Alta Town Center','6 - Passed','Raleigh-Durham-Chapel Hill, NC',336,2023,229166,77000000,'2025-11-06','2025-10-08','2025-11-10','All Docs Saved -  Hey Ethan, here’s our guidance email:
 
This is a great deal built by Wood & PGIM.  Guiding to $230K/unit, which is a realistic 5% Yr 1 cap (5% vacancy, 0% rent growth, 4% concessions).  If you burn concessions off entirely, it’s a mid-5% Yr 1.
 
Currently 94% leased, 5 net leases last week.  Concessions should start burning off soon, so there’s a strong rent growth story brewing. Related’s development in lease-up across the street, Town Triangle Crossing, is achieving $300 rent delta.
 
Let us know if you need anything or have additional questions as you underwrite.',TRUE,TRUE,''),
('Elan Prosperity Village','6 - Passed','Charlotte-Gastonia-Rock Hill, NC-SC',300,2024,266666,80000000,'2025-11-04','2025-10-07','2025-11-05','All Docs Saved - Ethan, 

We’re guiding $80M ($266k/unit), representing a 5.5% cap rate year 1 on in-place rents (no concessions), trending to a 5.65% cap on recent leases. 

Guidance is around replacement cost. There is one asset that just started site work in this submarket, and after that there are limited sites left for multi development, so the long term supply story is very good in this pocket. 

Micro-location Advantage: Prosperity Village stands apart from typical suburban Charlotte with its homogeneous, master-planned feel and walkability to three grocers plus a wide mix of quality retail (Chick-Fil A, Starbucks, Pure Barre). This differentiation has translated into the highest stabilized occupancy (94%+) and lowest concessions across northern Charlotte suburbs. Adding to the appeal, the submarket is zoned to a 7/10 elementary school and boasts median household income well above $100K.

We’ve outlined some additional highlights below — let us know if you’d like to schedule a call or tour:

Elan Prosperity Village / 2024 Vintage / 927 Avg SF 
•	Occupancy: 90% / 93% net-leased
•	 Avg In-Place Rent: $1,726 ($1.86 PSF)
o	Rents Trending Up - Last 2 Leases $1,771 (2.6% above RR)
o	~$100 rental headroom to NOVEL Mallard Creek ($1,826)
o	~$200 Rental headroom to Bainbridge Mallard Creek ($1,913)
•	Lease-Up & Operations: Averaged 20+ move-ins/month during lease-up; renewals averaging +1.5% with no concessions.
•	Submarket Performance: Prosperity Village leads Huntersville, Concord, Mallard Creek & University with highest occupancy and least concessions.
o	Example: Pointe at Prosperity – no concessions | Alta Croft – $750 off on select units. 
•	Schools & Demographics: Zoned for 7/10 Croft Community Elementary (greatschools.org) and next door to Corvian Charter School (9/10 – admission by lottery system). 
o	Rent Roll features highly curated resident base ($110k Avg HHI), 19% average rent-to-income ratio. 
•	Walkable Retail: Differentiated micro location adjacent to highly walkable Prosperity Village retail (Publix, Chick-Fil A, Starbucks, Pure Barre and many others). 
•	Employment Drivers: 
o	Located 7-minutes from University Research Park & Closer to Vanguard’s new 2,400 employee campus than Elan Research Park
o	<15 minutes to Booming Concord High Tech Manufacturing & Pharmaceutical Corridor
?	June 2024: Eli Lilly opens $2B Facility bringing 750 Jobs
?	July 2025: F1 Team Buys Site for $85M Manufacturing Facility Creating 350 Jobs averaging a salary of $100-125k. 
?	September 2025: $1.5B Red Bull Beverage Factory Begins Construction creating 700 jobs by 2028
?	Early 2026: Opening of Kroger’s 700-job fulfillment center',TRUE,TRUE,''),
('The Shore Luxury Apartment Homes','6 - Passed','Lakeland-Winter Haven, FL',300,2020,250000,75000000,'2025-11-03','2025-10-13','2025-11-05','All Docs Saved - Gentlemen,

We’ve been engaged to sell Shore Luxury Apartments, a 300-unit, 2020-vintage asset in Lakeland.   The seller is sensitive to marketing the property widely and disrupting their staff on site, so we have been asked to take the opportunity to a very short list of potential buyers.

If you’d be interested in the property, I have attached a CA, or you can sign online here.  

A few highlights to touch on:  

-	Shore Luxury is a very clean, well-designed asset with large average unit sizes (1,145 square feet).   
-	Consistent occupancy in the mid 90%’s with little to no concessions. 
-	Very high retention (close to 90% July – Sept 2025).
-	Owned and operated by original developer. 
-	Management upside (convert from manual rents to LRO-type of system,  bill for additional services like valet waste, leverage your existing portfolio to drive expense savings, etc.).  Current owner self-manages and only operates a couple of properties.  
-	Unique features including some units with extra half-baths or attached garages.  
-	Property boasts nearly 1 mile of shoreline along Long Lake giving most buildings great views.  
-	Lakeland is ranked the #1 market in nation for population growth %.  A lot of this growth is coming from Tampa and Orlando as the boundaries of these two markets push closer together.
-	Asset is located just off I-4 putting it close to significant job / demand drivers. 
-	Costar, Yardi and RealPage are projecting strong rent growth over the next few years due to strong job growth combined with a very limited supply pipeline.  There is zero new supply in a 3 mi radius.   There are just two assets under construction in a 5-10 mile radius.  
-	Lakeland has growing economic base and has become the e-commerce logistics hub of Florida due to its central location.   It is home to the corporate HQ for Publix (6,000 local employees and Florida’s highest ranked Fortune 500 company with $60B in revenue).   Other big employers include Lakeland Regional Health (6,000 local employees), GEICO (3,000 local employees), Amazon Air Hub (2,000), Watson Clinic (1,800),  Saddle Creek Logistics (1,200), Southeastern University (1,000), Rooms To Go (800), Advance Auto Parts (600), Florida Southern Collage (500), Summit Consulting (500), Primo Water (500), Southern Glazers Wine & Spirits (500).  

We expect the deal will price in the $250,000 per unit range, which puts the in-place cap rate at around 5% (T3 with adjust taxes).  You can use RealAdvice to do a purchase price allocation, which will reduce taxes and increase your cap rate meaningfully.  

Let me know your thoughts.',TRUE,TRUE,''),
('Newport Station','6 - Passed','Nashville, TN',192,2024,276041,53000000,'2025-10-30','2025-10-20','2025-10-30','All Docs Saved - Dear Ethan -

Thank you for your interest in our latest offering, Newport Station, a 192-unit Class A multifamily community built in 2024. The property has recently stabilized and is located in Thompson’s Station, one of the fastest-growing suburbs just 30 miles south of Nashville. Situated in Williamson County, the wealthiest county in Tennessee and home to the state’s top-ranked school system, Newport Station represents a premier investment opportunity.

Location Highlights:
•	1.5 miles from the new 700-acre June Lake master-planned community
•	2.4 miles from Interstate 65
•	2.5 miles from Publix, Kroger, Lowe’s, and Walmart Supercenter
•	15 miles from Franklin town center
•	16 miles from Cool Springs, McEwen Northside business district with over 9 million SF of office & 9.5 million SF of retail
•	30 miles from Downtown Nashville
Investment Highlights:
•	Exceptional lease-up velocity with strong effective rent growth
•	First-generation lease renewal rent growth upside
•	$41,400 additional annual revenue potential by adding fenced pet yards to 24 units
•	Price guidance at $276,000 per unit, equating to a 5.5% tax-adjusted cap rate on stabilized T1 and 6.00% Year 1 with conservative 3% rent growth assumptions
To access the deal room, please execute the CA via the link in the original announcement. 

CFO is set for 5pm October 30th; in the meantime, please reach to our Capital Markets team who have already sized the loan. 

Feel free to reach out with any questions or to schedule a tour. 

Best Regards,',TRUE,TRUE,''),
('Hillmeade Apartment Homes','6 - Passed','Nashville, TN',288,1986,232638,67000000,'2025-10-28','2025-09-16','2025-10-29','All Docs Saved - $67/$68M',TRUE,TRUE,''),
('Preston Ridge phase 2','6 - Passed','Hickory-Morganton-Lenoir, NC',1,NULL,NULL,NULL,NULL,'2025-09-19','2025-10-24','',FALSE,TRUE,''),
('Atria at Crabtree Valley','6 - Passed','Raleigh-Durham-Chapel Hill, NC',268,1987,149253,40000000,'2025-10-23','2025-09-16','2025-10-23','All Docs Saved  - 40m for Atria',TRUE,TRUE,''),
('Ashford Green','6 - Passed','Charlotte-Gastonia-Rock Hill, NC-SC',300,1995,210000,63000000,'2025-10-23','2025-09-16','2025-10-23','All Docs Saved  . 63m for Ashford',TRUE,TRUE,''),
('Mills Apartment Homes','6 - Passed','Greenville-Spartanburg-Anderson, SC',304,2014,194078,59000000,'2025-10-23','2025-09-25','2025-10-23','All Docs Saved  -- Ethan - Guidance is mid to upper $190k/unit which is a low 5% cap in-place based on today’s occupancy and concessions.
 
Built in 2014, The Mills is one of the most unique assets in Greenville with a low-density footprint (11 units/acre), large floorplans (974 SF), 9’ ceilings and direct entry into all units. Current ownership has fully renovated 25 units (9%) with Class-A finishes and are achieving premiums up to $250, providing the blueprint for new ownership moving forward. With a dwindling supply pipeline on the horizon, this pocket of Greenville is poised to see outsized rent growth of 16% through 2030 coupled with robust in-migration. 
 
The property’s location just off Woodruff Rd affords residents ease of access to major retail (Whole Foods, Trader Joes, Sprouts, Target, Haywood Mall) and the largest/highest paying employers downtown and surrounding the city (Prisma Health, Michelin, BMW). The immediate area is characterized by its excellent demographics with HHI’s exceeding $120k, soaring home values ($700k+) and top ranking schools.  
 
Let us know if you have any questions while digging in and when works best to set up a tour.',TRUE,TRUE,''),
('Preston Ridge','6 - Passed','Hickory-Morganton-Lenoir, NC',340,2020,205000,69700000,'2025-10-22','2025-09-16','2025-10-22','All Docs Saved - Hi Ethan,

+/- $205k per unit, which is a mid-5 cap on in-place NOI, tax- and insurance-adjusted. Let us know what questions we can answer. 

Thanks',TRUE,TRUE,''),
('Elme Watkins Mill','6 - Passed','Washington, DC-MD-VA',210,1975,209523,44000000,'2025-10-22','2025-09-16','2025-10-22','All Docs Saved - 
1.	Elme Watkins Mill – mid $40MMs, ~$210K/Unit, upper-5% to 6% in-place tax adjusted cap rate
2.	Elme Bethesda – ~$60MM, $310K/Unit, upper-5% to 6% in-place tax adjusted cap rate
3.	Elme Germantown – mid $50MMs, ~$250K/Unit, upper-5% to 6% in-place tax adjusted cap rate
4.	Kenmore – mid $70MMs, ~$200K/Unit, upper-5% to 6% in place tax adjusted cap rate
5.	3801 Connecticut - mid $70MMs, ~$240K/Unit, upper-5% to 6% in place tax adjusted cap rate',TRUE,FALSE,''),
('NoDa Flats','6 - Passed','Charlotte-Gastonia-Rock Hill, NC-SC',273,2020,274725,75000000,'2025-10-22','2025-09-17','2025-10-22','All Docs Saved - 75mm',TRUE,TRUE,''),
('Townhomes at Woodmill Creek','6 - Passed','Houston, TX',171,2015,304093,52000000,'2025-10-22','2025-02-13','2025-10-22','All Docs Saved - 
Update 3/12 - CFO''s being pushed back 30-60 days because of seller issues
$51.3mm… let us know how we can help.  This is a good one. 

$52M Now 9/30/25',TRUE,TRUE,''),
('Elme Germantown','6 - Passed','Washington, DC-MD-VA',218,1990,247706,54000000,'2025-10-22','2025-09-16','2025-10-22','All Docs Saved 1.	Elme Watkins Mill – mid $40MMs, ~$210K/Unit, upper-5% to 6% in-place tax adjusted cap rate
2.	Elme Bethesda – ~$60MM, $310K/Unit, upper-5% to 6% in-place tax adjusted cap rate
3.	Elme Germantown – mid $50MMs, ~$250K/Unit, upper-5% to 6% in-place tax adjusted cap rate
4.	Kenmore – mid $70MMs, ~$200K/Unit, upper-5% to 6% in place tax adjusted cap rate
3801 Connecticut - mid $70MMs, ~$240K/Unit, upper-5% to 6% in place tax adjusted cap rate',TRUE,FALSE,''),
('The Maggie Apartments','6 - Passed','Raleigh-Durham-Chapel Hill, NC',244,2014,344262,84000000,'2025-10-21','2025-09-18','2025-10-21','All Docs Saved TA owns it bought in Jan-22 for $91M

Hey, Ethan. Thanks for the note.

This is a special asset and we''re pumped to work on this one.
 
Pricing guidance is mid-$80Ms or $345-$350K/unit (mid/upper 4% cap in-place, 5% cap YR1).
 
This is a very compelling “restore-to-core” opportunity, located in the heart of Raleigh’s Village District. Current ownership has infused $4.2M+ of capital into the property, including clubhouse and amenity upgrades, and a proven value-add program on 36% of units generating $300+ avg. premiums. Offering no concessions, the property has witnessed 10%+ trade outs on renewals, all while maintaining 95% occupancy. 
 
With a 95 Walk Score, residents enjoy unparalleled convenience to 1M+ SF of retail in a 1-mile radius, including Fresh Market, Harris Teeter, Chick-fil-A, Sephora, and Onward Reserve, as well as seamless connectivity to Downtown Raleigh, NC State University, and 100k+ jobs within a 3-mile radius. 
 
Please let us know if you have any questions or if you’d like to set up a tour.',TRUE,TRUE,''),
('Preserve at Ridgeville Apartments','6 - Passed','Charleston-North Charleston, SC',240,2023,208333,50000000,'2025-10-21','2025-09-16','2025-10-21','All Docs Saved - 
Ethan, Low $50Ms range or $210K± per unit is guidance either FC or as an assumption.  The deal is just reaching stabilization. It is a mid 5% cap on FY1.',TRUE,TRUE,''),
('BLVD 2600 Luxury Apartments','6 - Passed','Orlando, FL',336,2023,244047,82000000,'2025-10-21','2025-09-18','2025-10-21','All Docs Saved - Guidance is $245K per unit, which is a 5.25% on in-place rents, mid-5%’s on recent leases, and high-5%’s when you factor in Live Local tax savings.

Key deal points– 

•	Suburban garden asset with expansive site plan, low-density feel (<10 units/acre), and lakefront nature trail. 
•	Strategic location with immediate access to 429/414 and less than 10 minutes to I-4. 
•	Proximate to Maitland Center jobs (20K Jobs, 8MSF office) and adjacent to Northrop Gruman (1K Jobs, 150K SF).
•	Barriers – 0 units UC within 4-mile radius. Only 2 market-rate properties delivered within a 4-mile radius in the last 5 years.
•	Live Local Tax Exemption in place. Estimated $234K in tax savings in 2025.',TRUE,TRUE,''),
('Biltmore at Camelback Apartments','6 - Passed','Phoenix-Mesa, AZ',270,2013,359259,97000000,'2025-10-28','2025-09-25','2025-10-16','All Docs Saved - 
Jay,
 
Guidance is $97M ($359k PU). Contract rents here are $900 below Cortland Biltmore, which is the closest comp.',TRUE,TRUE,''),
('Tresa At Arrowhead Apartments','6 - Passed','Phoenix-Mesa, AZ',360,1998,236111,85000000,NULL,'2025-09-30','2025-10-16','All Docs Saved - Jay, guidance is $85-$90 Mln.  

Jay – thanks for reaching out.  Guidance is $90,000,000 which is $250,000 per unit.  The building adjacent to Tresa at Arrowhead sold for $422,000 per unit in 2022 so Tresa is a significant discount to peak pricing and replacement cost.  The location is very good…Arrowhead Ranch is one of the premier master plans.',TRUE,TRUE,''),
('Arboretum at South Mountain Apartments','6 - Passed','Phoenix-Mesa, AZ',312,1999,272435,85000000,'2025-10-22','2025-09-17','2025-10-16','All Docs Saved - Hi Jay, 

Guidance is ±$85M.',TRUE,TRUE,''),
('The Highlands at Spectrum','6 - Passed','Phoenix-Mesa, AZ',284,2006,NULL,NULL,NULL,'2025-10-16','2025-10-16','All Docs Saved',FALSE,TRUE,''),
('Bungalows on Camelback','6 - Passed','Phoenix-Mesa, AZ',334,2024,324850,108500000,NULL,'2025-10-14','2025-10-16','All Docs Saved - Ethan 

Per my voicemail this afternoon, we guiding to +/- $325,000/unit ($108,500,000) on Bungalows on Camelback: 

Bungalows on Camelback (334 Units) - Phoenix, AZ
Key Investment Highlights: 
-	Built 2024, the property is comprised of 1-, 2- & 3-Bedroom Cottage-Style (BTR) Units with resort style amenities, thoughtful site planning and detached garage for-rent with an Avg. SF of 973, Market Rent of $2,031 or $2.08/sqft.
-	Unit Mix: 
o	1 x 1 (674 SF) – 20 Units (6%)
o	1 x 1 (676 SF) – 92 Units (28%)
o	2 x 2 (1,012 SF) – 147 Units (44%)
o	3 x 2 (1,355 SF) – 75 Units (22%)
-	Owner & Manager: 
o	Cavan Companies (Owner)  - merchant builder by trade, experienced track record with over 3,000 + BTR units in Arizona, Kansas City & Nebraska. 
o	RPM Living (3rd Party Mgmt) 
-	Offering Link (Document Center): 
o	https://properties.berkadia.com/bungalows-on-camelback-478952',TRUE,TRUE,''),
('Southpark Commons Apartment Homes','6 - Passed','Charlotte-Gastonia-Rock Hill, NC-SC',232,1986,163793,38000000,'2025-10-16','2025-09-09','2025-10-16','All Docs Saved 2/5 In a portfolio Hi Ethan - Thanks for reaching out. Guidance for the portfolio is low-$200mm which translates to high-$160 to low-$170K per unit. The offering can be acquired as a portfolio or on an individual asset basis. 

The assets currently participate in a voluntary income restriction program which qualifies the assets for tax exempt status in North Carolina. It''s important to note that the program can be terminated at the owners'' discretion at any time and without penalty.

Below is a summary of the yield profile on both an abated and unabated NOI…
 
•	Unabated (w/ taxes) = low-5.00% in place T3 income / Pro Forma Exp (w/ rent roll occ.)
•	Abated (w/o taxes) = Around a 6.00% in place yield on T3 income with Pro forma exp (w/ rent roll occ.)

Tours are encouraged and being hosted upon request. A call-for-offers date has not been set but anticipated to be early to mid-October.',TRUE,TRUE,''),
('Maeva Modern Apartments','6 - Passed','Tampa-St. Petersburg-Clearwater, FL',260,2023,220000,57200000,NULL,'2025-02-06','2025-10-14','All Docs Saved - Hi Ethan,
 
Thanks for reaching out…this is an interesting one. We have the pleasure of being the third broker, and there is a 99-year ground lease on the property. That said, we have a realistic seller at a very attractive basis and above-market yield! 
 
Pricing guidance is $215,000-220,000/unit, which is a 5.25% going-in cap rate (RR income/current concessions and stabilized other income and expenses). Meanwhile, it’s a 6.10% cap rate assuming rents marked to market and concessions burned off. Given the supply/demand dynamics in the submarket, this is achievable in the near future. 
 
What’s changed from last time(s):
•	The property is now officially stabilized. It’s 98% occupied and 98% leased.
•	Concessions are nearly burned off. ZERO concessions are being offered on new leases. They are offering 1 month free + a $1000 gift card on renewals but expect to eliminate that in the near-term.
•	Over 4,000 units delivered in this submarket in the past 24 months, and prior marketing efforts were launched during the height of the competition. Now, nearly all of that inventory is stabilized with less than 500 units left to be absorbed. 
•	Prior pricing guidance was $250,000/unit so you’re getting a steal!
 
Aside from the great basis and healthy yield, the property has some really compelling attributes:
•	4-story elevator product with great amenities, unique floor plan layouts, high-end finishes, and different themed courtyards in the center of each building.
•	Really strong tenant demographic profile - $163,727 avg HHI at the property - representing just a 15% rent-to-income ratio and setting the stage for healthy future rent growth potential.
•	Unique walkability to shopping and dining being adjacent to Cypress Creek Town Center (240,000 sf including a PopStroke) and a few blocks north of Tampa Premium Outlets (441,000 sf).
•	Pasco County is no longer just a commuter market. It now boasts a number of major job drivers, including 5 hospitals recently built or under construction and 8.5M sf of industrial space delivered and planned, all of which are bringing tens of thousands of jobs to the immediate area. 
 
It would be great to connect to discuss this one further. Do you have some time tomorrow or early next week?',TRUE,TRUE,''),
('Waterford Place Apartments','6 - Passed','Phoenix-Mesa, AZ',200,1984,220000,44000000,NULL,'2025-10-10','2025-10-14','All Docs Saved - Ethan,

Good to hear from you and thanks for reaching out on Waterford Place.  We think pricing will be in the mid $40m range which is around $220k - $230k a unit.  Patrick O’Donnell with Colliers Mortgage has posted loan quotes to the document center and is available to discuss different loan options.  I have copied him on this email so feel free to reach out to him directly.
 
Great Southeast Valley location just south of I-60 and Alma School with household income over $100k in a one-mile radius.  It is a Mesa address but acts more like Chandler and Gilbert because it is right on the border. 
 
200 units built in 1985 with washer/dryer in all the units.  Acacia Capital has held on to it for the last 20 years because it has been such a strong performer and now the loan is coming due.  It is a strong candidate for a value-add program by repositioning the clubhouse and renovating the units.  Approximately 40% of the property is classic and the rest of the units have been partially upgraded.  Let me know your availability to jump on a call to discuss the current renovations, our proposed renovations, and where we think you can take the rents.
 
Highlights:
1.	96% Occupancy with consistently strong operating history
2.	Limited Local Supply with zero units under construction within two miles
3.	Value-add opportunity
4.	Desirable East Valley location with easy access to US-60, Loop-101, and the Price Corridor, one of metro Phoenix’s premier employment hubs with 44,000+ jobs.
 
Major Economic Drivers:
1.	Banner Desert Medical Center – 3.2 miles | 6,500+ jobs
2.	Downtown Mesa - 4 miles | 15,750+ jobs
3.	Wells Fargo – 6.5 miles | 5,500+ jobs
4.	Price Corridor - 7.8 miles | 44,000+ jobs
5.	Downtown Tempe - 9 miles | 40,000+ jobs
6.	Downtown Phoenix - 18 miles | 53,000+ jobs
 
Waterford Place is located in one of Phoenix’s most supply-constrained areas, with zero new multifamily projects under construction within two miles of the property.  It shows very well so let us know when you would like to tour.
 
Best regards,',TRUE,TRUE,''),
('Monte Viejo','6 - Passed','Phoenix-Mesa, AZ',480,2004,225000,108000000,NULL,'2025-10-10','2025-10-14','All Docs Saved - $225k - $230k per unit.',TRUE,TRUE,''),
('Niche | Luxury Apartments','6 - Passed','Tampa-St. Petersburg-Clearwater, FL',251,2024,318725,80000000,'2025-10-28','2025-09-23','2025-10-14','All Docs Saved - Hi Ethan,

Our pricing guidance on Niche is $80M / $318k per-unit equating to a 5.00% in place cap rate (RR income/T12 expenses, 80% tax adj) and a 5.47% Yr. 1 cap rate, achievable through property/market trends highlighted below: 
 
Differentiated Product Driving Sustainable Growth:
•	2024 built, 6-story wrap 
•	In-place rents at Niche are $450 below the comparable set and $1,000+ below Downtown Tampa comps
•	Robotic Ori Furniture in high demand floorplans, with 8.40% rent growth over the last 15 months
 
Core Quality Asset at Core-Plus Returns:
•	Niche stabilized within 6-months of C/O 
•	7.12% net effective lease trade outs (5.87% gross on new leases / 4.18% gross on renewals)
•	3.30% Yr. 1 rent growth projections (Co-Star)
•	Positive leverage day one!
•	9% ULIRR and 13%+ LIRR 
 
North Hyde Park - A Premier Live Work Play Neighborhood
•	Within 10-minutes of 175,000+ jobs (Downtown Tampa - 5-minute drive / Westshore Business District - 10-minute drive)
•	78 Walk Score - 46 walkable retail options
•	$181,662 Average Household Income (14% of in-place rents)
•	Zero new supply under construction within submarket
 
Let us know if there is a good time to schedule a call to discuss in more detail, or to arrange a property tour.',TRUE,TRUE,''),
('NOVEL Scott''s Addition by Crescent Communities','6 - Passed','Richmond-Petersburg, VA',275,2024,363636,100000000,NULL,'2025-10-02','2025-10-14','All Docs Saved - Hey Ethan – hope you guys are well. 

We’re guiding to the low $100M mark, which is a 5.25% cap on stabilized UW. This is the nicest and most amenitized asset in the market, and the first of institutional quality to hit the market in Scott’s Addition. Despite that, we still are inside replacement costs for this quality of build, and minutes away from CoStar’s new US HQ, which will have over 3500 jobs when build out is complete, which will be late spring/early summer of 2026. Additionally, we are directly across the street from Richmond’s new baseball stadium, the first of several phases for Richmond’s $2.5B Diamond District Development.',TRUE,TRUE,''),
('Prose Desert River','6 - Passed','Phoenix-Mesa, AZ',384,2024,264322,101500000,NULL,'2025-08-26','2025-10-14','Coming Soon  No Docs',FALSE,TRUE,''),
('Montreux','6 - Passed','Phoenix-Mesa, AZ',335,2020,283582,95000000,NULL,'2025-09-05','2025-10-14','All Docs Saved - No guidance on this one Jay.',TRUE,TRUE,''),
('Residences at Stadium Village','6 - Passed','Phoenix-Mesa, AZ',382,2009,248691,95000000,'2025-10-15','2025-09-15','2025-10-14','All Docs Saved Ethan, thanks for reaching out.  Pricing expectations for RSV is $95 million reflecting a 5.5% cap on T12 financials.  This pricing will support fresh agency financing in the mid to hi 60% range or Debt fund at or above 70% LTV',TRUE,TRUE,''),
('Park 67 Apartments','6 - Passed','Phoenix-Mesa, AZ',160,1973,187500,30000000,NULL,'2025-09-17','2025-10-14','All Docs Saved - Thank you for your interest in Park 67, a 160-unit, institutionally maintained community located in Glendale, one of the Phoenix MSA’s most densely populated submarkets (CA: RCM Deal Room Link). Park 67 combines recent heavy capital investment with a proven value-add program, offering durable in-place cash flow alongside clear upside potential. More details on the offering below:
•	Guidance: $30,000,000
•	Tours: Please reach out to Emily Soto to schedule onsite tours
•	Financing: Please reach out to Brandon Harrington and Bryan Mummaw to discuss new financing options 
•	Call for Offers: October 14th 
 
Deal Highlights: 
 
Proven Value-Add Upside
•	81% of units are fully renovated, with upside remaining to renovate the final 19% of classic units. 
•	Additional revenue opportunities include installing washers/dryers (+$75/unit/month premium, city-approved) and entering a bulk internet/smart home program (+$40/unit/month net).
 
Significant Capital Investment Completed
•	Over $4.2M invested since 2021, including new roofs installed in 2022 under a 10-year warranty, major system upgrades, extensive interiors, and amenity enhancements. 
•	The heavy lifting has been completed, allowing the next investor to focus on revenue-driving improvements.
 
Favorable Supply/Demand Dynamics
•	With only 68 multifamily units under construction within three miles, the Glendale submarket is highly supply-constrained, positioning Park 67 for steady rent growth with limited new competition. 
•	The one-mile radius demographic highlights that 67% of the population identifies as a renter vs homeowner, solidifying the strong long-term demand for multifamily in the submarket.
 
Robust Demographics & Employment Drivers
•	Nearly 500,000 residents and 109,000+ jobs are located within five miles. 
•	Employers include Luke Air Force Base, Banner Thunderbird Medical Center, Midwestern University, and the Westgate Entertainment District anchored by State Farm Stadium and Desert Diamond Arena.
 
Operational & Financial Advantages
•	Extremely low property taxes ($210/unit annually) and a balanced 50/50 unit mix of one- and two-bedrooms. 
•	Pro forma NOI exceeds $2.0M, supported by ancillary income streams including RUBS, storage, laundry, and technology packages.
 
 
Major Economic Drivers Near Park 67 (within 5-20 minute drive)
•	Westgate Entertainment District & State Farm Stadium – A premier retail, dining, and entertainment hub anchored by the Arizona Cardinals’ stadium and Desert Diamond Arena, driving year-round traffic, jobs, and tourism.
•	Luke Air Force Base – One of the nation’s largest fighter pilot training facilities, employing over 7,500 military and civilian personnel, with a multi-billion-dollar annual economic impact.
•	Banner Thunderbird Medical Center – A 513-bed hospital and Level I Trauma Center, serving as one of Glendale’s largest employers and healthcare anchors.
•	Midwestern University – Enrolling 3,700+ students with 660 faculty/staff, fueling consistent housing demand from graduate students and healthcare professionals.
•	Tanger Outlets Phoenix – A major retail destination drawing consistent employment and foot traffic.
•	Downtown Glendale – A growing cultural and local business hub, home to restaurants, shops, and annual events like Glendale Glitters.',TRUE,TRUE,''),
('The Jeffersonian','6 - Passed','Charlottesville, VA',83,1968,240963,20000000,NULL,'2025-10-09','2025-10-14','All Docs Saved - 
Ethan,

We’re guiding to $20M, reflecting a 5.6% in-place cap and 5.75% Yr 1 yield. The property is 100% occupied with no concessions, YoY organic rent growth of 11% (15.6% on trade outs, 6.7% renewals), and offers potential for a value-add program to unlock additional upside.

The 2-acre site also offers a compelling development opportunity with substantial cash flow during the planning and entitlement phase. The site is zoned NX-10 with 10 stories permitted as matter-of-right with the potential for up to 13 stories through bonus provisions. This development site offers the same potential as The Verve currently under construction on the other side of campus. 

This is a truly irreplaceable location directly adjacent to UVA''s campus, the UVA Law and Darden Business schools, and a short walk to JPJ Arena, Barrack Road Shopping Center and other key Charlottesville amenities. 

Let’s schedule a call to discuss after you’ve had the chance to underwrite.',FALSE,TRUE,''),
('Revel Ballpark','6 - Passed','Atlanta, GA',275,2019,305454,84000000,'2025-10-14','2025-09-17','2025-10-14','All Docs Saved - Ethan,

Appreciate you reaching out.
 
Revel Ballpark is a 2019-built Atlantic Residential deal walkable to The Battery (2M SF mixed-use development) and Truist Park in Cobb County.
 
Pricing guidance is $84M ($305K/unit), which is a 4.84% T1 cap rate (299c tax freeze through 2026). This is a 5.56% Y1 cap rate including a core plus renovation strategy and 50% penetration of the other income upside.
 
The property is in a privately gated neighborhood which gives it a superior setting while having access to 700K+ jobs within ~20 minutes.
 
Cumberland has experienced incredible population growth—outpacing the national average by 7.6x and the already strong Atlanta MSA by 3.2x. This has been a driver for the submarket''s 24% 5-year historical rent growth. 
 
Below are a few other property-level highlights as well:
•	$124K Avg. HHI
•	95% Avg. 12-month occupancy
•	Signing Leases 3.5% above in-place rents
•	66% Retention with ~3.0% renewal increases
•	18 bps of T12 Bad Debt Write-Offs
 
When are you available for a call / tour?',TRUE,TRUE,''),
('Vue on Lake Monroe','6 - Passed','Orlando, FL',280,2019,232142,65000000,'2025-10-09','2025-09-10','2025-10-10','All Docs Saved - Ethan,

Guidance for the Vue on Lake Monroe is $65.8M or $235K per door which is a 5.25% T3 tax-adjusted cap rate and 5.5% Yr. 1 with a 3rd party projected rent growth and a slight reduction in concessions.

The Vue on Lake Monroe is fully stabilized, 4-story elevator-serviced lakefront asset that was built in 2020 and features an expansive clubhouse amenity footprint overlooking Lake Monroe and well-appointed unit interiors with granite countertops, imported Italian cabinetry, subway tile backsplash, upgraded Whirlpool stainless-steel appliances with refrigerators featuring indoor ice and water dispensers, plank flooring throughout the living rooms and wet areas, and upgraded bathroom vanities.

The asset is located directly on Lake Monroe in the Sanford/Lake Mary submarket and sits adjacent to the HCA Lake Monroe Sanford Hospital and less than 15 minutes from the heart of the Lake Mary office market (10M SF of office). The Sanford/Lake Mary submarket also benefits from limited future supply as there is only 1 deal delivering within a 3-mile radius of the property and nothing else planned on the horizon.

Current ownership has received Live Local (SB102) qualifications on 77 units and is currently receiving a 75% tax abatement on those qualified units. They are in the process of qualifying additional units which should present further upside and additional yield creation for new ownership.

Please let us know what questions you have as you review or if you''d like to schedule a tour of the property.',TRUE,TRUE,''),
('Boulders Lakeview','6 - Passed','Richmond-Petersburg, VA',212,2023,250000,53000000,'2025-10-09','2025-09-08','2025-10-10','All Docs Saved, No OM - Ethan – 

Apologies for the delay here! Below is the rundown, are you free to jump on a call to discuss? Helps to provide additional color. 

-	Guidance: $53M, or $250k/unit, priced at a significant discount to replacement costs for 2023 vintage product. 
-	Location: 
o	Boulders Lakeview sits in the Boulders Office Park in North Chesterfield, an office park comprising over 1M SF of Class A office and serving as the main office park for the Chesterfield market. 
o	Benefiting from a Chesterfield address but still in close proximity to Downtown employers (10 mins), Scotts Addition and Stony Point retail scene (both 10 mins away), and several big box grocers, Boulders Lakeview attracts a core renter focused on convenience and proximity to employers. 
-	Property Specifics:
o	Year built: 2023
o	Occupancy: 96% (as of 9/4/2025)
o	Number of units: 212
o	Average in-place rent: $1,666, but most recent 2 and 5 leases signed of all floorplans average $100 higher than in-place. 
o	Unit Mix: 116 1BR units, 92 2BR units.  
-	Property Story:',TRUE,TRUE,''),
('Avant at Fashion Center','6 - Passed','Phoenix-Mesa, AZ',335,2017,340298,114000000,'2025-10-09','2025-09-02','2025-10-10','All Docs Saved - 340k/unit',TRUE,TRUE,''),
('Palmetto Place','6 - Passed','Charlotte-Gastonia-Rock Hill, NC-SC',184,1996,146739,27000000,'2025-10-08','2025-09-18','2025-10-09','All Docs Saved Hey Ethan,

We are guiding $27M / $147k per unit which is a mid-5 Y1 cap rate. This is going out on a very limited basis so we are encouraging quick pricing feedback and will tour those that can get to guidance or within 1%.  We sold this in ’21 at the peak so good relative value.',TRUE,TRUE,''),
('ParkView Greer Apartments','6 - Passed','Greenville-Spartanburg-Anderson, SC',257,2023,214007,55000000,'2025-10-07','2025-09-04','2025-10-07','All Docs Saved - Ethan,

Hope you''re doing well, sir. Appreciate you reaching out.
We''re targeting the $55M range, shakes out around a 5.36% cap rate on our stabilized NOI of $2.95M.  You''ll notice we''re not including the retail space income in the NOI until year 2, so it''s not factored into our valuation.  
We see the upside in this investment is purchasing below replacement costs, increasing rents (there''s a story why they''re in the bottom 1/3 of market), and filling the retail spaces.  The location of Park View is one of the best in Greer.
We''re targeting CFO the week of October 7th.
Please shoot us any questions in the process, and we''ll schedule a call once you''ve had an opportunity to review.
Thank you,',TRUE,TRUE,''),
('Paces Pointe Apartment Homes','6 - Passed','Charlotte-Gastonia-Rock Hill, NC-SC',336,1987,163690,55000000,NULL,'2025-09-09','2025-10-02','All Docs Saved 3/5 in a portfolio - Hi Ethan - Thanks for reaching out. Guidance for the portfolio is low-$200mm which translates to high-$160 to low-$170K per unit. The offering can be acquired as a portfolio or on an individual asset basis. 

The assets currently participate in a voluntary income restriction program which qualifies the assets for tax exempt status in North Carolina. It''s important to note that the program can be terminated at the owners'' discretion at any time and without penalty.

Below is a summary of the yield profile on both an abated and unabated NOI…
 
•	Unabated (w/ taxes) = low-5.00% in place T3 income / Pro Forma Exp (w/ rent roll occ.)
•	Abated (w/o taxes) = Around a 6.00% in place yield on T3 income with Pro forma exp (w/ rent roll occ.)

Tours are encouraged and being hosted upon request. A call-for-offers date has not been set but anticipated to be early to mid-October.',TRUE,TRUE,''),
('Caveness Farms Apartments','6 - Passed','Raleigh-Durham-Chapel Hill, NC',288,1997,163194,47000000,NULL,'2025-09-09','2025-10-02','All Docs Saved - 5/5 in a portfolio Hi Ethan - Thanks for reaching out. Guidance for the portfolio is low-$200mm which translates to high-$160 to low-$170K per unit. The offering can be acquired as a portfolio or on an individual asset basis. 

The assets currently participate in a voluntary income restriction program which qualifies the assets for tax exempt status in North Carolina. It''s important to note that the program can be terminated at the owners'' discretion at any time and without penalty.

Below is a summary of the yield profile on both an abated and unabated NOI…
 
•	Unabated (w/ taxes) = low-5.00% in place T3 income / Pro Forma Exp (w/ rent roll occ.)
•	Abated (w/o taxes) = Around a 6.00% in place yield on T3 income with Pro forma exp (w/ rent roll occ.)

Tours are encouraged and being hosted upon request. A call-for-offers date has not been set but anticipated to be early to mid-October.',TRUE,TRUE,''),
('Central on the Green Apartment Homes','6 - Passed','Raleigh-Durham-Chapel Hill, NC',200,1986,165000,33000000,NULL,'2025-09-09','2025-10-02','All Docs Saved - 4/5 in a portfolio Hi Ethan - Thanks for reaching out. Guidance for the portfolio is low-$200mm which translates to high-$160 to low-$170K per unit. The offering can be acquired as a portfolio or on an individual asset basis. 

The assets currently participate in a voluntary income restriction program which qualifies the assets for tax exempt status in North Carolina. It''s important to note that the program can be terminated at the owners'' discretion at any time and without penalty.

Below is a summary of the yield profile on both an abated and unabated NOI…
 
•	Unabated (w/ taxes) = low-5.00% in place T3 income / Pro Forma Exp (w/ rent roll occ.)
•	Abated (w/o taxes) = Around a 6.00% in place yield on T3 income with Pro forma exp (w/ rent roll occ.)

Tours are encouraged and being hosted upon request. A call-for-offers date has not been set but anticipated to be early to mid-October.',TRUE,TRUE,''),
('Bridges at Mallard Creek Apartment Homes','6 - Passed','Charlotte-Gastonia-Rock Hill, NC-SC',184,1988,163043,30000000,NULL,'2025-09-09','2025-10-02','All Docs Saved 1/5 in Portfolio Hi Ethan - Thanks for reaching out. Guidance for the portfolio is low-$200mm which translates to high-$160 to low-$170K per unit. The offering can be acquired as a portfolio or on an individual asset basis. 

The assets currently participate in a voluntary income restriction program which qualifies the assets for tax exempt status in North Carolina. It''s important to note that the program can be terminated at the owners'' discretion at any time and without penalty.

Below is a summary of the yield profile on both an abated and unabated NOI…
 
•	Unabated (w/ taxes) = low-5.00% in place T3 income / Pro Forma Exp (w/ rent roll occ.)
•	Abated (w/o taxes) = Around a 6.00% in place yield on T3 income with Pro forma exp (w/ rent roll occ.)

Tours are encouraged and being hosted upon request. A call-for-offers date has not been set but anticipated to be early to mid-October.',TRUE,TRUE,''),
('Elme Marietta','6 - Passed','Atlanta, GA',420,1975,145238,61000000,NULL,'2025-09-16','2025-10-02','All Docs Saved - Elme Marietta (420 Units, 1975)
-	Price: $61MM (~$145K/unit)
-	Cap Rate: ~5.5% (Current), ~6% Year 1 Cap Rate, ~7.0% (Un-trended Stabilized YOC)
-	~40% of units to be renovated',TRUE,FALSE,''),
('Elme Sandy Springs','6 - Passed','Atlanta, GA',389,1972,151670,59000000,NULL,'2025-09-16','2025-10-02','All Docs Saved - Elme Sandy Springs (389 Units, 1972)
-	Price: $59MM (~151K/unit)
-	Cap Rate: ~5.6% (Current), ~6% Year 1 Cap Rate, ~7.5% (Un-trended Stabilized YOC)
-	35% of units to be renovated
-	60% of units are townhomes',TRUE,FALSE,''),
('Elme Conyers','6 - Passed','Atlanta, GA',240,1999,150000,36000000,NULL,'2025-09-16','2025-10-02','All Docs Saved - Elme Conyers (240 Units, 1999)
-	Price: $36MM (~$150K/unit)
-	Cap Rate: ~5.15% (Current), 5.7% Year 1 Cap Rate, ~6.9% (Un-trended Stabilized)
-	90% of units to be renovated',TRUE,FALSE,''),
('Hawthorne Westside','6 - Passed','Charleston-North Charleston, SC',200,1984,190000,38000000,'2025-10-14','2025-09-04','2025-10-02','All Docs Saved - Ethan – thank you for reaching out. Pricing guidance is $190-$195k/unit which is a tax and insurance adjusted mid-5% cap rate based on T3 numbers and an upper-5% cap Year-1. 

Hawthorne Westside represents an outstanding opportunity to acquire a well-capitalized, mid 1980’s multifamily asset located in a desirable West Ashley submarket. West Ashley is the one of the last remaining value neighborhoods in the Charleston MSA boasting the strongest occupancy out of all the submarkets in the Charleston MSA (96.4%) with minimal oncoming supply (0 units u/c in 3-mile radius). 

The property has experienced strong demand, with a +10% lift in recent trade-outs, setting the stage for continued rental growth. New ownership has the opportunity to capture significant upside through the completion of the proven interior renovation program by bringing all remaining classic and partially renovated units up to the “dream” level. "Dream" units are currently achieving premiums of ~$250. Submarket comparables also demonstrate substantial rental headroom, with a potential delta exceeding $400.

Deal Room: Hawthorne Westside 

Call for Offers is set for October 14th. Please let us know if you have any questions when you start digging in.',TRUE,TRUE,''),
('Dwell @ 750','6 - Passed','Atlanta, GA',312,1975,157051,49000000,'2025-10-14','2025-09-04','2025-10-02','All Docs Saved - Ethan,

Guidance here is $49M-$51M, which is $157K-$163K/unit, which is a 6.30% tax adjusted, pro forma expenses cap rate, with the ability to be pushed north of 7.50% through interior value-add and organic rent growth.
 
Let us know if you’d like to hop on a call or set up a tour. 
 
Dwell @ 750 // Marietta, GA // 312 Units // Built 1975/2025 
•	Link to Confidentiality Agreement for Financials: HERE
•	Asset Highlights:  
o	Occupancy: 95% Occupied; Avg. Mkt Rent: $1,537 ($1.56/ft). 
o	Since 2013, ownership has invested $9.8M+ into major capital improvements, including unit renovations, the addition of 8 new units, window and siding replacements, exterior paint, as well as a newly updated leasing office and pool area. 
o	This is a well-maintained asset comprises of 288 classic units and 24 renovated units. A new owner has the opportunity to renovate the remaining classic units (92%) to the renovated scope for an expected ROI of 28%+. 
•	Submarket Highlights:   
o	Located in one of Atlanta’s most sought-after suburban submarkets, Dwell @ 750’s immediate area boasts an average household income of $105K+ and average home values of $481K+.
o	Marietta offers a dynamic lifestyle amenity mix including a high concentration of national retail centers, premier dining destinations, and leading entertainment districts including the $672M Truist Park/The Battery mixed-use development, situated just 10 minutes from Dwell @ 750. 
o	Cobb County, the 3rd most populous County in Georgia, is home to multiple Fortune 500 companies, including The Home Depot and Genuine Parts (NAPA). In 2024, Cobb County attracted more than $136M in new commercial investment from 18 project wins.',TRUE,TRUE,''),
('Corwyn South Point','6 - Passed','Atlanta, GA',260,2022,219230,57000000,NULL,'2025-09-24','2025-10-02','All Docs Saved - Ethan- 

Target price on Corwyn is $220,000’s/unit range.  CFO in 3 weeks. 

Upside:
1) Marketing 2-yrs ago achieved $245,000/u, seller pulled, now $25k/u less.
2) August T1 in-place cap is 5.75% with normalized occupancy/concessions.  
3) Year 1 cap rate is 6.5% through:
     -Return To Peak Rents adds $235k (temp supply caused 5% rent drop)
     -Reserve Parking/Tech Pack adds $90k

Intrinsic Value:
4) 20% below replacement costs (Costs $275,000/u today).  
5) Next door & nearby AA sales sold at $280k to $300k/u.
6) Better value: Northern suburbs rents only 10-15% more but trade 25-30% higher.  


Do you have time today or tomorrow to discuss or set a tour? 

David',TRUE,TRUE,''),
('Village Highlands','6 - Passed','Atlanta, GA',258,2005,155038,40000000,'2025-10-03','2025-09-25','2025-10-02','All Docs Saved - Jay - Wanted to make sure you saw this one.  It''s a 2005 expiring LIHTC deal with solid in-place yield and easy upside.  Great product and proven blueprint.
The deal was successfully taken through QC in 2023 and is currently in its 2nd year of the 3-year decontrol period.  As affordable unit leases expire and the tenants vacate, ownership can then convert that unit to a fully market rate unit (+$375).
Guidance is $40M-$41M ($155k-$159k/unit) which is a going-in 5.76%-5.90% Cap on T3/Yr 1 Pro Forma Expenses. New ownership will be able to push north of a 7% cap through organic upside alone rolling rents to market before implementing a value add which will push north of an 8.50% cap in years 2 and 3.
At present, roughly 52% of the property is still subject to affordability restrictions however starting in 2027 the property can be converted to 100% market rate without any restrictions regardless of existing affordable unit status. Furthermore, current market rate units have all classic interiors, so they are effectively a blank canvas for value add to compete with its new market rate competitive set with demonstrated rental headroom of +$400.
 Let us know if you''re interested and we can get you more detail. 
Listing Website: https://multifamily.cushwake.com/Listings/31667',TRUE,TRUE,''),
('Overture Doral','6 - Passed','Miami, FL',198,2020,429292,85000000,'2025-10-09','2025-09-08','2025-10-02','All Docs Saved - Mid to high $80M’s
JS: age restricted, OM not out but does not look like there is any value-add, nice location',TRUE,TRUE,''),
('Aspire Gateway','6 - Passed','Tampa-St. Petersburg-Clearwater, FL',329,2001,243161,80000000,'2025-10-09','2025-09-04','2025-10-02','All Docs Saved - ZRS/TruAmerica - Hi Ethan,

We’ll be targeting $80M ($243,161/unit), which is a 5.3% cap rate on in-place with adj taxes. More to come next week!',TRUE,TRUE,''),
('Elofts','6 - Passed','Washington, DC-MD-VA',200,2016,375000,75000000,NULL,'2025-09-15','2025-10-02','All Docs Saved - $75M guidance, built 2017, loan assumption in low 4s.',TRUE,TRUE,''),
('Sanctuary at West Port','6 - Passed','DaytonaBeach, FL',360,2018,225000,81000000,'2025-10-02','2025-08-20','2025-10-02','All Docs Saved - Hey guys – Sanctuary at WestPort is a terrific deal.  Pricing expected around $81-82M.  5.6% cap year 1. $220s per unit…awesome basis for newer product in a strong and growing part of Central Florida. Really nice property with interior air-conditioned corridors, huge amenity footprint, elevators in two buildings. Has some solid upside too. 

Let us know if you’d like to tour. 

Shelton',TRUE,TRUE,''),
('Seapath on 67th','6 - Passed','Myrtle Beach, SC',224,2018,194196,43500000,NULL,'2025-09-23','2025-10-02','All Docs Saved - Hi Ethan,
Thanks for reaching out for Seapath on 67th, a premier asset in the Grande Dunes neighborhood, Myrtle Beach’s most sought after location. 
 
We are guiding in the mid to high $190s/unit which represents a mid-5% cap year one and a high teens IRR. The asset is offered significantly below replacement cost and includes a compelling value-add angle with the opportunity to push rents $200 - $250 bringing rental rates in line with nearby competitors. The property is a ten minute walk from the beach, located just off of HWY 17, and includes a best in class amenity package.  
 
Our view of the value-add execution with this asset is that by painting the exterior a color scheme that is more in-line with new construction in the market and lightly renovating the already well appointed interiors (backsplash, goose neck faucets, smart home features), Seapath on 67th should be able to leverage its strong location and like-new finishes to lead the submarket in rents. 
 
Property Website: https://www.seapathon67.com/
 
Seapath on 67th | Myrtle Beach, SC | 224 Units | Built 2018
•	Sought-After Grande Dunes Pocket
o	1-Mile Demos: $151K+ Avg. HHI, 76% White-Collar, 46% Bachelor’s Degree +, $1M+ Avg. Home Values
o	1 Mile from Fresh Market, Publix, Intracoastal Waterway, Oceanfront, Grand Strand Medical Center, & Grande Dunes (2M SF of retail & commercial properties completed & underway)
o	Dwindling Supply: No Multi developments under construction within a 5-mile radius of the property 
o	Myrtle Beach named fastest-growing city in the U.S. for third year in a row
•	Institutional Grade Product with Value Add Upside
o	Class-A Interiors: 9 ft ceilings, granite counters, shaker style cabinetry, oversized walk-in closets, stainless steel appliances, W/D appliances, vinyl flooring, private patios/balconies
o	Full Suite Amenity Package: 2 pickleball courts, resort-style pool, dedicated golf cart parking, 10 minute walk to the beach, multiple grilling stations, dog park, elevators, fitness center, EV charging stations, yoga studio
o	Value Add Interior Availabilities: Tile backsplashes, smart home features, gooseneck faucets, rain shower heads, single basin sinks. 
o	Additional income available via implantation of a Cable/internet package, smart home feature integration and Wash/Dryer capitalization.
 
Deal Room: Seapath on 67th 
 
CFO: Will be set at a later date, but late October is expected.',TRUE,TRUE,''),
('Trelago Apartments','6 - Passed','Orlando, FL',350,2019,322857,113000000,'2025-10-09','2025-09-17','2025-10-02','All Docs Saved - Guidance is $325-330K per unit. CFO 10/9.

Key deal points –

•	Low-density lakefront Related product w/ best in submarket amenities
o	W&D sold to Kettler/PacLife in December 2019 for $300k per unit (formerly Town Trelago)
•	Unit upside – smart locks/thermostats, bulk WiFi, plank flooring, lighting upgrades & closet systems
•	Growing mixed-use Trelago development
o	Trelago Market (65K SF retail) fully leased, only 3 F&B concepts open so far
o	Sails of Trelago (70K SF retail) 80% leased, permitted, construction imminent
o	85 For-Sale 3-Story Townhomes (David Weekley under contract)
o	Last remaining parcel (3 acres) UC to retail developer (likely 30k SF)
•	Barriers – 0 units UC within 5-mile radius
•	Top demographics both on-site & surrounding rings
•	Proximate to white-collar jobs, upscale entertainment/shopping, specialty grocers & abundant parks/green space
o	Less than a mile from I-4
 
Given the unique combination of attributes above, particularly the 165,000 SF of incoming retail out front, and our position in the submarket, Trelago is primed for a light interior upgrade program & outsized organic rent growth moving forward.',TRUE,TRUE,''),
('Innsbrook Square Apartments','6 - Passed','Richmond-Petersburg, VA',305,2023,278688,85000000,'2025-10-07','2025-08-26','2025-10-02','All Docs Saved - Ethan -

Innsbrook Square is a 305-unit, 2023 vintage asset located in Innsbrook, providing future ownership with immediate scale and management efficiencies in Richmond''s premier Western Henrico submarket.

Guidance is mid-280k per unit, equating to a 5.50% Year 1 Cap Rate. A few additional deal highlights are below:

•	Strong Leasing Trends: Recent new-leases are 15.00%+ above in-place rents, underscoring the depth of demand for luxury living in this submarket. With the largest floorplans in Innsbrook, comprised of nearly 40% 2-bedroom units, Innsbrook Square provides exceptional value per square foot while maintaining a significant delta to rents at the top of the competitive set. Innsbrook Square is well positioned to continue recognizing outsized rental rate growth YoY.

•	Discount to Replacement Cost: At guidance, Innsbrook Square represents a meaningful discount to today''s replacement cost, with comparable development estimated at $310,000-$320,000 per unit. Within the immediate area, only one property is under construction and two are proposed, further insulating Innsbrook Square from future development pressure.

•	Affluent Renter Base: Average Household Income in a 1-mile radius is over $200,000 and is projected to grow nearly 15% through 2030. This renter base is able to absorb significantly higher rents, giving future ownership the ability to drive sustained rent growth and long-term value creation.

•	Desirable Location and Amenities: Located just minutes from the area’s top schools and commercial/lifestyle locations - including Innsbrook Office Park (22,000 employees), West Creek Office Park (12,000 employees), Short Pump Town Center (1.5MSF of retail), and West Broad Marketplace (386KSF), Innsbrook Square offers residents unmatched access to jobs, retail, and entertainment. With a large pool complete with a sundeck, outdoor fire tables, grill areas, club and game room, and a paved trail, Innsbrook Square is thoughtfully designed for a best-in-class living experience.',TRUE,TRUE,''),
('Bridges at Chapel Hill','6 - Passed','Raleigh-Durham-Chapel Hill, NC',144,1990,159722,23000000,'2025-10-07','2025-03-11','2025-10-02','All Docs Saved - 

$23-23.5M (low $160Ks/u) – 5 cap on T12 and will be 5.25 on T1 once Concessions burn-off in Aug financials 



Bridges is low 170s per unit.',TRUE,TRUE,''),
('Bryant at Summerville','6 - Passed','Charleston-North Charleston, SC',232,2004,219827,51000000,'2025-10-07','2025-08-25','2025-10-02','All Docs Saved - $51M - $52M on Bryant at Summerville / $220Kish per unit / about 5.25% in place cap rate',TRUE,TRUE,''),
('Urban 148','6 - Passed','Phoenix-Mesa, AZ',148,1973,202702,30000000,'2024-12-05','2024-11-20','2025-10-01','All Docs Saved - Thanks for reaching out on Urban 148.  The seller’s loan is maturing at the end of the year, so we are doing an expedited sales process by collecting offers on December 5th.  The Seller has the option to extend his loan, so the goal is to have a solid buyer picked before the holidays and then execute the extension based on the PSA timeline.  The seller has put a lot of work into this asset since they purchased it in 2019 and originally preferred to execute a refinance vs selling at today’s pricing.  However, the refinance option is not as palatable as originally expected so they must move forward with the disposition.  Price is important and you will find a recent appraisal for $33.7M in the document center that was going to be used for the refinance.  Just as important will be the buyer’s reputation for certainty of close with no re-trade.  With that in mind we expect the deal to trade ± $30M, which is a 6.27% cap on T3 income /T12 expenses @ 90% occupancy. If you move the occupancy and rents back to market, then you’re at a 7% cap without having to do any heavy lifting.  Ownership has spent approximately $50k per door in renovations over the last 5 years curing deferred maintenance and renovating all of the unit interiors to the same level.

 

Modern Turnkey Community

Current ownership spent $7.1M in capital improvements, including $5.1M on interior renovations
All units have been renovated to the same scope with a high end, luxury finish
Units average 1,023 SF with all two and three bedroom floorplans. All units have in-suite washers & dryers, modern finishes, private balconies/patios and select units have vaulted ceilings
Ownership installed new individual HVAC’s and efficient tankless water heaters
 

Dynamic Infill Location:

Located five minutes from historic Uptown Phoenix with trendy restaurants, boutiques, coffee shops, and highly desirable single family homes
Average home sales price of $1,385,265 within the last 6-months in the central corridor between 7th Street and 7th Avenue, Bethany home Rd and Northern Ave (58 sales)
Strong area demographics with average household income of $100,000+ (1-mile radius) and projected population growth of 3.1%
Exceptional in-fill location with only 3 properties built in the last 30 years (2 mile radius)
1,465,000 jobs in a 30 minute commute shed, with less than a 15 minute commute to the Biltmore, Downtown Phoenix, and the Central Ave and Camelback Road corridors.
Notable employers within 5-miles include Dignity Health (4,760 jobs), Banner Health (2,360 jobs), VA Medical Center (3,500 jobs), Grand Canyon University (3,930 jobs), Charles Schwab (2,090 jobs), St. Joseph’s Medical (1,450 jobs), Blue Cross Blue Shield (1,990 jobs), State of AZ (3,520 jobs)',TRUE,TRUE,''),
('Reserve at Greenwood','6 - Passed','Greensboro--Winston-Salem--High Point, NC',240,2021,225000,54000000,NULL,'2025-09-03','2025-10-01','All Docs Saved - 
Ethan,

Thank you for reaching out regarding Reserve at Greenwood—this is an exceptional opportunity to acquire a premier asset in one of Greensboro’s most desirable submarkets. Located just off Battleground Avenue near Pisgah Church Road, Reserve at Greenwood is the only new-construction rental option in the area, offering unmatched positioning and upside potential.

•	Pricing Guidance: Low-mid $50Ms, or mid ~$220Ks per unit which equates to a mid-5 cap rate on trailing T3/T12 and can be pushed to approximately 6% + FY1 by rolling recent leases and initiating light operational value-add and closing the gap on top of the market competitors.
•	Asset Highlights 
o	Occupancy: 98% (100% leased as of 8/26/25); Avg. Rent $1,563; Avg SF: 1,058
o	T6 NRI Growth ~9% +
o	Light value-add / Mark-to-Market: Ability to push rents into the mid $1,650s as the property lags top of the market by $150-$200+ 

Link to CA & Landing Page – Reserve at Greenwood - Document Center

CFO will be announced shortly, but likely be the week of October 1st.

Let me know if you have any questions—happy to jump on a call this week at your convenience just let me know.',TRUE,TRUE,''),
('The Cooper','6 - Passed','Charleston-North Charleston, SC',344,1987,299418,103000000,NULL,'2025-08-27','2025-10-01','All Docs Saved - Ethan – thanks for reaching out. Guidance is $300k-$305k/unit which is a tax and occupancy adjusted ~5.25% cap today and a 6% on recent leases. Following the completion of the proven value-add in year three, this pushes to a 6.5% yield on cost.  

Mt. Pleasant is one of the most coveted submarkets in the Southeast and is the fastest growing and most affluent in the Charleston, MSA. It’s highly supply-constrained environment with unmatched demand fundamentals created from a long-standing multifamily moratorium that prevents any new development. The immediate area surrounding The Cooper is characterized by its top tier, affluent demographics boasting $155k average household income and $900k+ avg home values within 1 mile.

The 32-acre site is walkable to Class-A retail (Whole Foods, Starbucks, Harris Teeter, Gwynns), dining, major economic drivers, entertainment (Patriots Point Golf Course, MP Memorial Waterfront Park, CoC Baseball Stadium, CHS Battery Soccer Stadium), and some of the region’s most desirable beaches. 

The Cooper’s strong leasing momentum with 10%+ recent trade outs positions the asset to generate continued rental upside through the completion of the proven value-add across the remaining 43% of the unrenovated units which are achieving $300 - $500 premiums. The submarket leader, Legacy at Patriot’s Point,  has a $3k rent delta over The Cooper and doesn’t provide the same retail walkability.

Please let us know if you have any questions when you start digging in.',TRUE,FALSE,''),
('The Statler','6 - Passed','Phoenix-Mesa, AZ',240,2024,275000,66000000,'2025-10-01','2025-08-26','2025-10-01','All Docs Saved - $66M from John Cunnigham, other 2 brokers on team said $68M',TRUE,TRUE,''),
('Emblem Riverside','6 - Passed','Atlanta, GA',425,2022,225882,96000000,NULL,'2025-09-10','2025-09-30','All Docs Saved - Off mkt',TRUE,TRUE,''),
('New River Cove Apartments','6 - Passed','Fort Lauderdale-Hollywood, FL',316,1999,303797,96000000,'2025-10-07','2025-09-16','2025-09-30','All Docs Saved - Ethan,

They do not need to go together and ownership (Starwood) does not have a preference toward a two-asset or single-asset execution – maximizing proceeds is most important. Please see below for pricing guidance. We are very excited about these opportunities and feel each asset has unique aspects that differentiates it in the marketplace. 
 
•	Oasis Delray Beach: North of $355k/unit (~$350/sf), which is a 5% T3/T12 tax & ins. adjusted cap rate getting to a 5.8% un-trended stabilized cap rate through completion of unit interior renovations.
 
•	New River Cove: North of $305k/unit (~$250/sf), which is a 5.25% T3/T12 tax & ins. adjusted cap rate getting to a 6% un-trended stabilized cap rate through completion of unit interior renovations.',TRUE,TRUE,''),
('2211 Grand Isle Apartments','6 - Passed','Tampa-St. Petersburg-Clearwater, FL',390,1999,241025,94000000,NULL,'2025-09-24','2025-09-30','All Docs Saved - This is a pre-marketing announcement for 2211 Grand Isle.  The property is an exceptional value-add investment opportunity in Tampa.  This is an exclusive Avison Young listing.  We are only contacting a select number of investors at this time.

•	Prestigious infill location within the highly desirable Brandon submarket - Tampa Bay MSA.
•	Outstanding access to the Crosstown/Selmon Expressway and I-75. Downtown Tampa 15 minutes, I-75 Employment Corridor 20 minutes and Westshore Business District / Tampa Airport 30 minutes.
•	390 units built in 2000. Occupancy 97%. In-Place Rent $1,713
•	Highly attractive two-story property with large floor plans.  Average size is 1,026 square feet per unit.
•	All units have first floor direct entry.  Ceiling heights are approximately nine feet on the first floor and vaulted thirteen feet on the second floor.
•	High-end gated community. Amenity package includes exquisite, large clubhouse, resort inspired pool, sports court, large fitness center, dog park, and playground.
•	Potential to increase rents on approximately 63% of the units through a value-add program that includes hard-surface counter tops and a new appliance package.
•	Document Center with Preliminary Property Information
•	Property Website
•	Google Map',FALSE,TRUE,''),
('Connecticut Heights Apartments','6 - Passed','Washington, DC-MD-VA',518,1974,231660,120000000,NULL,'2025-09-29','2025-09-30','Signed CA - Guidance is +/- $120m, ~ 230k per unit, which is 6.5% cap on in place T3 tax adjusted. The OM will be ready this week. 
If it''s interesting let me know and we''ll set up a tour.',FALSE,TRUE,''),
('The Glen at Lanier Crossing','6 - Passed','Atlanta, GA',264,2003,164772,43500000,'2025-09-30','2025-08-27','2025-09-30','All Docs Saved - $165k/door range. Owners basis is $220k/door, basically selling for the lender. Long story short.',TRUE,TRUE,''),
('Paragon Luxury Apartments','6 - Passed','Athens, GA',240,2022,210000,50400000,'2025-09-30','2025-08-21','2025-09-29','All Docs Saved - Ethan - guidance is $210k’s PU. The property is high 90%’s leased and just raised rents and implemented some additional income charges providing a path to the high 5%’s in the first year.  Great resident profile, strong recent leasing activity, and some distinct micro location advantages relative to the comps. Happy to hop on a call to discuss further.',TRUE,TRUE,''),
('Heritage Estates Apartments','6 - Passed','Orlando, FL',230,2003,226086,52000000,'2025-10-01','2025-08-27','2025-09-29','All Docs Saved - ZRS Managed - Ethan, 
Good to hear from you on this one! 
Guidance on Heritage Estates Apartments is $52M+ ($226K PU / $195 PSF) which equates to an in-place cap rate of 5.55% using current collections, T3 other income and T12 expenses – and a 6.4% Year 1 cap rate. 
This is a value-add opportunity with nearly 60% of units positioned for a full renovation scope featuring quartz countertops, undermount sinks, updated cabinet fronts, new lighting fixtures, smart thermostats, and LVT flooring in select units. Additional upside also exists with some underutilized clubhouse space which can be repurposed into additional amenities space such as a co-working area.  
The 230-unit community, built in 2003, is in the premier East Orlando submarket which has benefitted from limited new supply with only five apartment communities delivered since 2010 and no properties under construction within a 3-mile radius. Heritage Estate’s location provides immediate access to SR-408 and Alafaya Trail, delivering direct connectivity to Orlando’s major economic drivers including the University of Central Florida (13,000+ employees), Central Florida Research Park (10,000+ employees), and Lockheed Martin’s rotary and mission systems training facility that sits just five minutes from the property.  Additionally, Heritage Estates is located five minutes from Waterford Lakes Town Center, Florida’s premier lifestyle destination spanning 700,000 square feet and attracting over 14.3 million annual visitors, providing unrivaled shopping, dining, and entertainment. 
Some additional investment highlights include:
•	Adjacent Development Opportunity: 10-Acre neighboring vacant land parcel is available with the apartments for potential future expansion.
•	Impressive Access to Top Tier Higher Education: 10 minutes from the University of Central Florida, the state’s largest university by enrollment, providing access to a dynamic community of approximately 70,000 students and over 13,000 employees.
•	Rare Opportunity to Collapse COA And Convert to Traditional Multifamily: Strategic fractured condo business plan with 85% ownership already achieved, creating a compelling value-add opportunity to acquire remaining units and convert to traditional multifamily operations.
Please let us know if you would like to set-up a call once the OM is released next week or schedule a tour.',TRUE,TRUE,''),
('The Mason Sugarloaf','6 - Passed','Atlanta, GA',312,2022,259615,81000000,'2025-09-24','2025-08-13','2025-09-26','All Docs Saved - Ethan- 
Targeting $260k/unit this time.  Marketed it 2 years ago and got to $280k/unit.  We pulled it.  Jay, call me and I can walk through the change and what has happened since.',TRUE,TRUE,''),
('Bell Lighthouse Point Apartments','6 - Passed','Fort Lauderdale-Hollywood, FL',249,2015,301204,75000000,NULL,'2025-08-27','2025-09-25','All Docs Saved - Hi Ethan,

Guidance is $75 - $76 million, or low $300s per door. Well below replacement cost for six-story mid-rise product with structured parking.

Let us know if you’d like to schedule a call to discuss further or arrange a tour.

All the best,
Kaya',TRUE,TRUE,''),
('The Kensington at Halfmoon','6 - Passed','Albany-Schenectady-Troy, NY',200,2014,300000,60000000,NULL,'2025-09-16','2025-09-24','All Docs Saved - Looking for $60m. Mid 5% cap. Let us know when you would like to discuss further or tour.',TRUE,FALSE,''),
('Monterosso Apartments','6 - Passed','Orlando, FL',216,2020,208333,45000000,'2025-09-22','2025-08-27','2025-09-24','All Docs Saved - Ethan,

Pricing guidance on Monterosso is $45M or around $210K per door, which is a 5.25% trailing cap rate adjusted for stabilized vacancy, and post-sale taxes. With a slight reduction in concessions and expenses, the year 1 cap rate moves to a 5.75%.

The property is 2020 product, featuring 4-story elevator-serviced buildings with interior conditioned corridors and a large integrated amenity set for the unit count (216 units). Interior finishes are in-line with brand new comps in the submarket and feature quartz counters, stainless-steel appliances, and plank flooring throughout ground floor units.

Current ownership has had some operational struggles as this is their only asset in Central Florida and there has been a large amount of staffing turnover at the property. They recently replaced the on-site team and regional manager and are working to re-stabilize the asset (currently 86% occupied). 

The Property has a great location in the middle of The Loop in South Orlando and is walkable to 1M SF of destination retail and restaurants and less than 10 minutes from multiple hospital systems providing more than 500 hospital beds. Additionally, the Property sits only 15 minutes from the entrance to Walt Disney World, the largest single-site employer in the country with 77K+ employees. 

Let us know what questions you have as you review or if you would like to schedule a tour of the property.',TRUE,TRUE,''),
('Fairways at Lake Mary','6 - Passed','Orlando, FL',272,1998,268382,73000000,'2025-09-23','2025-08-19','2025-09-23','All Docs Saved - Ethan,

Pricing guidance on Fairways at Lake Mary is $73M - $74M or high-$260K''s per door which is a 5.25% trailing, tax-adjusted cap rate and an upper 5% Yr. 1 after factoring in renovation premiums and some 3rd party projected market rent growth.

The Property is a 1998 built, 2-story product with 100% private direct entries and direct-access garages into every unit. The asset is located in the heart of the highly affluent Lake Mary submarket and is walkable to the Orlando Health Lake Mary campus, AdventHealth Lake Mary Health Park, and a Publix-anchored shopping center. The property is currently 96% occupied with a 60-day trend of 96% occupancy and has not offered any concessions over the last year. Additionally, there is minimal future supply within a 3-mile radius with only one other project delivering in 2025 and nothing planned on the horizon. 

Current ownership has kept the property extremely well-maintained, having invested $5.3M+ of capital into the property since acquiring it in 2019. They have renovated approximately 67% of the units under their hold which are achieving $150-$250+ rent premiums over the classic units (33%), providing new ownership a proven-out value-add renovation program and additional rent upside. 

Let us know what questions you have as you review or if you''d like to schedule a tour of the property.',TRUE,TRUE,''),
('Effingham Parc Apartments','6 - Passed','Savannah, GA',352,2009,227272,80000000,'2025-09-22','2025-08-21','2025-09-23','All Docs Saved - Guys, I love this deal for Stonebridge!!! Thanks for your interest in the opportunity,  Your team should be all over this offering, it has exceptional operating trends and material value-add potential.
Good schools, high employment growth corridor and limited directly competing new supply and very strong performance trends, with 100% of units eligible for renovations/premiums. 
 
There is also an (optional) assumable loan that may be very accretive to the deal; depending on your business plan.
 
Pricing guidance is in the ~$80M range. We will CFO the third week of September, likely around the 9/18. 
 
Effingham Parc - Document Center
 
Best
-Dave',TRUE,TRUE,''),
('Village at Olive Marketplace','6 - Passed','Phoenix-Mesa, AZ',208,2021,298076,62000000,'2025-09-23','2025-07-31','2025-09-23','All Docs Saved - Jay- Whisper price is $62M. It’s a T-30 5.00% cap rate and 5.75% cap rate if you mark rents to where they have been signing recently at $2.06 psf and burn off concessions.',TRUE,FALSE,''),
('The Addison Eighty50','6 - Passed','Charlotte-Gastonia-Rock Hill, NC-SC',339,2023,247787,84000000,'2025-09-23','2025-08-19','2025-09-23','All Docs Saved - Hey, Ethan. Hope all is well.

Pricing guidance is mid-$80Ms or $250Ks/unit (5% Cap YR 1).  
 
This property is poised benefit from Pharma, Healthcare, Finance and Manufacturing employment expansions along the North Charlotte / I-85 corridor:  Eli Lilly, Vanguard, Amazon, Atrium Health, Wells Fargo, Redbull, Hendrick Motors, and Cadillac to name a few.  Additionally, Cabarrus County is experiencing dramatic reduction in multifamily supply due to water/sewer capacity issues at the Rocky River treatment plant.  We are bullish on this combination of strong demand with supply constraints.
 
The property also received a favorable assessed value that is locked in until 2028.
 
Google Maps - The Addison Eighty50
Property Website - Addison Eighty50
 
We have uploaded all UW materials to the Deal Room, linked below.  The OM will become available next week.  Please let us know if you have any questions or would like to schedule a tour to see the property.',TRUE,TRUE,''),
('Village at Almand Creek','6 - Passed','Atlanta, GA',236,2002,152542,36000000,'2025-09-23','2025-09-10','2025-09-23','All Docs Saved - Shooting for $36-$38M ($160k/unit). The per unit and PSF is below where we are seeing some 8’ trades here in Atlanta. Prior owner paid $250k/unit. The physical asset is in great condition with the lender focusing on cleaning up any deferred and capex but leaving the interiors alone for the next group. There is already a strong in-place value add spread on the renovated units. Currently trending to a high 5% cap rate with room to push into the sixes. 
 
Let me know if you would like to get out and see this one later this week or next week or set up a call.',TRUE,FALSE,''),
('Crowne Gardens Apartments','6 - Passed','Greensboro--Winston-Salem--High Point, NC',344,1998,180000,61920000,NULL,'2025-02-13','2025-09-22','All Docs Saved - This is a great deal. New Roofs, New Siding, No Poly, WD hook-ups in all units. Minimal deferred. See below for more detail. You can sign the CA here. 
 
Crowne Gardens was built in 1998 and has been owned and managed by Crowne Partners, the original developer, since inception. The property is performing very well at 94% occupancy and demonstrates great trends with on T-1, T-3, T-6 heading into peak leasing season. Guidance is $61,920,000, representing a 5.50% cap rate on T-3 revenues, T-12 expenses. At $180,000 per unit, Crowne Gardens is offered at a significant discount to replacement cost. 
 
65 of the units have been renovated and are achieving average premiums of $305/unit/month. Significant value-add upside remains by adding premium finishes to the 120 classic units and the 159 moderately renovated units. The fully renovated apartments at Brassfield Park (1996 vintage, 973 Avg. SF) are achieving rents in the $1,750/unit/month range, representing a delta of $500/unit/month above the unrenovated units at Crowne Gardens. The Grove at Kernersville (2015 vintage) sold for $265/unit in February 2022 (15 miles away).
 
The asset was originally built to condo-quality standard with 9 ft. ceilings, 1,100 sf. units, and benefits from a history of exceptional stewardship and preventative maintenance by ownership. The property is located adjacent to major retailers Fresh Market, Target, Harris Teeter, Lowes Food, Home Depot, and Walmart. It is also an ideal commuter location with immediate access to I-73 and I-840.
 
We will be touring Tuesday and Wednesday of next week.',TRUE,TRUE,''),
('The Perry','6 - Passed','Washington, DC-MD-VA',297,2016,521885,155000000,NULL,'2025-09-08','2025-09-22','All Docs Saved - Hi Ehtan,

Guidance is $155M which is a 5% cap on in-place once you back out the NPV of the 55% LTV debt at 2.75% interest only fixed for five years. Can also put on a supplemental that takes you to 65% LTV at a blended 3.25% rate…will be well north of an 8% cash on cash. Pushing out trade outs around 10% right now with almost 70% retention.

Let me know if you want to connect on it.',TRUE,TRUE,''),
('Oasis Delray Beach Apartments','6 - Passed','West Palm Beach-Boca Raton, FL',324,19982013,354938,115000000,NULL,'2025-09-16','2025-09-22','All Docs Saved - 40% was built in 2013 - Ethan,

They do not need to go together and ownership (Starwood) does not have a preference toward a two-asset or single-asset execution – maximizing proceeds is most important. Please see below for pricing guidance. We are very excited about these opportunities and feel each asset has unique aspects that differentiates it in the marketplace. 
 
•	Oasis Delray Beach: North of $355k/unit (~$350/sf), which is a 5% T3/T12 tax & ins. adjusted cap rate getting to a 5.8% un-trended stabilized cap rate through completion of unit interior renovations.
 
•	New River Cove: North of $305k/unit (~$250/sf), which is a 5.25% T3/T12 tax & ins. adjusted cap rate getting to a 6% un-trended stabilized cap rate through completion of unit interior renovations.',TRUE,TRUE,''),
('The Hudson at Cane Bay','6 - Passed','Charleston-North Charleston, SC',300,2021,233333,70000000,'2025-09-23','2025-08-26','2025-09-22','All Docs Saved - 
Ethan,

Glad you are interested in this one as it is a great opportunity to acquire a core+ asset with walkability to Publix. The properties rents are poised to run as the most proximate supply completes lease-up, and disruption from the road-widening subsides. We expect pricing to be in the low to mid $70 million range which is an FY1 mid 5% cap. Let’s set up a call to discuss this week.

Thanks,',TRUE,TRUE,''),
('Elevate at Brighton Park','6 - Passed','Charleston-North Charleston, SC',329,2019,276595,91000000,NULL,'2025-08-25','2025-09-22','All Docs Saved - $91M - $92M on Elevate / upper $270Ks per unit / about 5.0% in place cap rate',TRUE,TRUE,'')
ON CONFLICT (name) DO NOTHING;

INSERT INTO deals (name,status,market,units,year_built,price_per_unit,purchase_price,bid_due_date,added,modified,comments,flagged,hot,broker) VALUES
('12th & James Luxury Apartments','6 - Passed','Atlanta, GA',214,2002,186915,40000000,NULL,'2024-12-05','2025-09-19','All Docs Saved - Thank you for the note. We’re targeting ~$185K per door / ~$40M / ~6% Year 1 yield. Let’s connect once you’ve had a chance to review the materials.',TRUE,TRUE,''),
('Vlux at Queen Creek','6 - Passed','Phoenix-Mesa, AZ',240,2023,300000,72000000,'2025-09-18','2025-07-23','2025-09-18','All Docs Saved - Thank for your interest in the Phoenix VLUX Portfolio.  The portfolio consists of three cottage style BTR communities featuring single family style living with each home offering a private backyard, spacious living space, high end finishes and a complete amenity package.
 
The offering can be acquired as a portfolio or individually with expected pricing to be in the $175M+ range for the portfolio (approximately $280K per unit).  Pricing on an individual property basis breaks down as:
 
•	VLUX at Queen Creek | Approximately $72M / $300,000 per unit
•	VLUX at Peoria Heights | Approximately $54M / $287,500 per unit
•	VLUX at Sunset Farms | Approximately $49.5M / $255,000 per unit
 
We have not established a bid date yet but expect to do so in the next week or so.  Once a bid date has been set, we will send out an announcement so you can plan accordingly.
 
Again, thank you for your interest and please let us know if you would like to schedule a call to discuss the offering in more detail or if you would like to schedule a tour of the properties',TRUE,TRUE,''),
('VLux at Peoria Heights','6 - Passed','Phoenix-Mesa, AZ',188,2023,287234,54000000,'2025-09-18','2025-07-23','2025-09-18','All Docs Saved - Thank for your interest in the Phoenix VLUX Portfolio.  The portfolio consists of three cottage style BTR communities featuring single family style living with each home offering a private backyard, spacious living space, high end finishes and a complete amenity package.
 
The offering can be acquired as a portfolio or individually with expected pricing to be in the $175M+ range for the portfolio (approximately $280K per unit).  Pricing on an individual property basis breaks down as:
 
•	VLUX at Queen Creek | Approximately $72M / $300,000 per unit
•	VLUX at Peoria Heights | Approximately $54M / $287,500 per unit
•	VLUX at Sunset Farms | Approximately $49.5M / $255,000 per unit
 
We have not established a bid date yet but expect to do so in the next week or so.  Once a bid date has been set, we will send out an announcement so you can plan accordingly.
 
Again, thank you for your interest and please let us know if you would like to schedule a call to discuss the offering in more detail or if you would like to schedule a tour of the properties',TRUE,TRUE,''),
('Vlux at Sunset Farms','6 - Passed','Phoenix-Mesa, AZ',194,2023,255154,49500000,'2025-09-18','2025-07-23','2025-09-18','All Docs Saved - Thank for your interest in the Phoenix VLUX Portfolio.  The portfolio consists of three cottage style BTR communities featuring single family style living with each home offering a private backyard, spacious living space, high end finishes and a complete amenity package.
 
The offering can be acquired as a portfolio or individually with expected pricing to be in the $175M+ range for the portfolio (approximately $280K per unit).  Pricing on an individual property basis breaks down as:
 
•	VLUX at Queen Creek | Approximately $72M / $300,000 per unit
•	VLUX at Peoria Heights | Approximately $54M / $287,500 per unit
•	VLUX at Sunset Farms | Approximately $49.5M / $255,000 per unit
 
We have not established a bid date yet but expect to do so in the next week or so.  Once a bid date has been set, we will send out an announcement so you can plan accordingly.
 
Again, thank you for your interest and please let us know if you would like to schedule a call to discuss the offering in more detail or if you would like to schedule a tour of the properties',TRUE,TRUE,''),
('Presley Oaks','6 - Passed','Charlotte-Gastonia-Rock Hill, NC-SC',318,1996,213836,68000000,'2025-09-17','2025-08-14','2025-09-17','All Docs Saved - Hey Ethan,

Guidance is $215K/unit which is north of a 5.5% cap on the T3. Could be a nice addition to your two in University. CFO is 9/17. 

5-year agency debt with a buy down is sizing to 70% leverage at a 4.90% all in rate. The W&D debt matrix is available in the deal room. 

Presley Oaks is a well-maintained asset that underwent a full renovation by Cortland between 2016-2018, followed by an additional $1.7M in enhancements by American Landmark over the past seven years. Recent upgrades include 9 roofs, smart locks, custom built-in closets, LVP flooring in select units, and Nest thermostats in select units. 

Despite these improvements, Presley Oaks maintains up to a $175 rent gap to proximate, similar-vintage assets, presenting a clear value-add 2.0 opportunity. This strategy includes updating kitchen tile backsplashes, painting cabinetry, and completing LVP flooring and Nest thermostat installations across the remaining units.

We’ve provided some additional details below but let us know if you would like to schedule a call or tour.

Presley Oaks / 1996 Vintage / 318 Units/ 9’ Ceilings
•	96% occupied on the T12 with no concessions and <1% Bad Debt
•	$1.7M invested by current ownership including 9 new roofs over the past year
•	Differentiated amenity set both in-unit and across common areas:
o	9’ Ceilings, custom built-ins in master bedroom closets and nest thermostats/Smart Locks
o	Two-story gym + additional outdoor gym, recently remodeled resort style pool, and 112 attached garages
•	Adjacent to Future Red Line Light Rail Stop / Harris Station – Charlotte is moving forward with the red line commuter rail including a planned stop adjacent to Presley Oaks. 
o	City Finalizes $91M Purchase of O-Line Railroad from Norfolk Southern
o	Red Line Map
•	Barbelled by future light rail stop and Griffith Lakes Master Planned Community.
o	Homes selling into the $800Ks with 800K SF of office and retail planned. 
•	10-minute drive from University City (80K Jobs), Charlotte’s 2nd largest employment node & Vanguard’s New 2,400 Employee Campus which opened in May 2025
•	Exceptional Access to Various Retail & Dining Options – 4.4M+ SF of Retail Within a 3-Mile Radius
o	Across the Street from Harris Teeter-Anchored Shopping Center + Starbucks & Chick-Fil-A',TRUE,TRUE,''),
('Waterstone','6 - Passed','Atlanta, GA',296,2011,219594,65000000,'2025-09-10','2025-08-14','2025-09-16','All Docs Saved - Ethan,

Our pricing goal is to minimize loan impairment on loan basis of ~$65M, whether through an outright purchase option or a recap/restructure option. Call for offers is in four weeks.

Happy to discuss further.',TRUE,TRUE,''),
('Park Place Oviedo Apartments','6 - Passed','Orlando, FL',275,2015,298181,82000000,NULL,'2024-07-29','2025-09-11','All Docs Saved - 
Now with W&D Off Market

Pricing guidance is $81 million to $85 million (high $200,000’s – low $300,000’s per unit), which yields an in-place adjusted cap rate around 5%.     The deal underwrites to a low teens IRR with new debt and offers strong upside potential with the ability to update a majority of the interiors.

We view Park Place as one of the most unique and irreplaceable assets in the suburban Orlando market due its location with the Oviedo on the Park mixed-use development.   Oviedo on the Park is a walkable, dynamic town center, which gives Park Place a distinct competitive advantage over most of its comp set.    The neighborhood includes street level retail, restaurants, a food hall, fitness concepts, a park, a dog park, a lake with paddleboats, and a concert venue.   The area boasts high home values, strong demographics, great schools, and very limited new supply. 

If you have any further questions, we can set up a call or arrange a time for a tour.',TRUE,TRUE,''),
('Wisconsin House','6 - Passed','Washington, DC-MD-VA',109,1957,201834,22000000,NULL,'2024-08-07','2025-09-10','All Docs Saved - Hey Jay,

+/- $22 million, ~ $200k per unit.

Let me know when you want to tour it.

Also, 38 parking spaces.',TRUE,TRUE,''),
('The Park at Catania Apartment Homes','6 - Passed','Orlando, FL',360,1993,166666,60000000,NULL,'2025-08-27','2025-09-08','All Docs Saved - Hey guys - The Park at Catania is a great property. Infill location near tons of demand drivers; most of the comps are institutionally owned; really strong operational and value add upside here.  Can be purchased free & clear or through assumption of the existing loan with a fixed rate of 3.98% and plenty of leverage.  Pricing guidance around $60-$61MM ($160,000s/unit)….around a 5.6% cap going in north of a 6% year 1.

Let us know if you have questions or would like to tour.',TRUE,TRUE,''),
('The Henry','6 - Passed','New York, NY-NJ',169,2001,384615,65000000,'2025-09-17','2025-07-15','2025-09-08','All Docs Saved - $65MM',TRUE,TRUE,''),
('Waterleaf at Murrells Inlet','6 - Passed','Myrtle Beach, SC',240,2018,225000,54000000,'2025-09-09','2025-08-07','2025-09-08','All Docs Saved - Ethan,

Here are the key details on Waterleaf at Murrell’s Inlet:
•	Pricing: $54 million, which is $225k/unit. This equates to a 5.25% T12/T12 cap rate, with a clear path to a successful value-add program as well as already-proven organic rent growth.
•	Doc Center: Link to OM, financials, demographics, etc.: https://clientportal.berkadia.com/captureemail/006Pf00000YB1YMIA1 
•	Financing: Berkadia’s debt team of Jeremy Lynch and Jake Adoni (Philadelphia Office) have provided various financing options. A debt matrix is available in the Doc Center.
•	Tours & Offers: Offers will be reviewed and responded to as they are received. All offers are due by 5p ET on Tuesday, Sept 9. Tours require a 48-hour notice for scheduling with our team.',TRUE,TRUE,''),
('South Beach Portfolio','6 - Passed','Miami, FL',125,NULL,240000,30000000,NULL,'2025-07-29','2025-09-08','All Docs Saved - Sentinel is seller  10 Properties',FALSE,TRUE,''),
('Halcyon at Cross Creek','6 - Passed','Greenville-Spartanburg-Anderson, SC',152,1995,164473,25000000,'2025-09-09','2025-07-30','2025-09-08','All Docs Saved - Will – As discussed, same owner as Independence Park. See attached for the latest financials for Halcyon at Cross Creek in Greenville, SC.  Please keep very confidential. Pricing guidance is $165-$170k/unit. 
 
Halcyon comes with highly unique floorplans, including massive units (1,412 average square feet), and also offers a prime location: 6 miles from the BMW Plant, 3 miles from the Prisma Health Campus, 2 miles from Pelham Road, and 6 miles from Downtown Greenville. Halcyon''s micro-market boasts outstanding fundamentals, including almost no supply (only 252 units planned within 3 miles), an exceptional school system (7/10 rating or higher), and projected household incomes expected to surge over 16%, reaching over $132,000 by 2029.
 
Property trends are performing exceptionally well on both sides of the T12 (96% occupied currently and over the T3), all while offering minimal concessions over the same time period. Ownership has also received updated insurance quotes at approximately $700 per unit, which should be reflected in the financials soon. Recent operations allow you to pivot to completion of the in-place value-add to the remaining 89 units (approximately 60% of remaining units). Renovated units are achieving $125 premiums. Current renovations include faux granite countertops in kitchens and bathrooms, stainless steel appliances, new cabinets, brushed nickel hardware, vinyl flooring, new lighting and plumbing fixtures, and ceiling fans. Based on nearby competitors, there is strong support for an enhanced renovations across all units, including granite and tile backsplash to achieve $200-$250 premiums.
 
The property also presents the opportunity to build another 70 units, facilitated by its low density and unused acreage. Current ownership has priced out initial quotes for building 56 one-bedroom units that are 700 average square feet, along with a new clubhouse. Plans are attached.
 
Let us know if you have any questions throughout your underwriting.',TRUE,TRUE,''),
('Retreat at the Park','6 - Passed','Greensboro--Winston-Salem--High Point, NC',249,2015,209839,52250000,'2025-09-11','2025-08-18','2025-09-08','All Docs Saved - Ethan,

Here are the key details on Retreat at the Park:
•	Pricing: $52.25M, which is $209k/unit. This equates to a 5.15% T12/T12 cap rate, with a clear runway to implement a value-add program. Rents have increased 7% year-over-year.   
•	Doc Center: Link to OM, financials, demographics, etc.: https://properties.berkadia.com/retreat-at-the-park-443177/
•	Financing: Berkadia’s debt team of Tucker Knight and Clay Faust (Houston Office) have provided various financing options. A debt matrix is available in the Doc Center.
•	Tours & Offers: Offers will be reviewed and responded to as they are received. All offers are due by 5p ET on Thursday, Sept 11. Tours require a 48-hour notice for scheduling with our team.
•	A few notable tidbits:
o	The property has 73% 2 and 3BR units. The average sq. ft  is 992.
o	99% of the tenants are at <100% AMI. 54% are <80% AMI.
o	Over the last year, 71% of tenants renewed their lease.
o	The in-place rent-to-income ratio is 20%, well below the national average of 30%.',TRUE,TRUE,''),
('The Addison Longwood','6 - Passed','Orlando, FL',277,2024,259927,72000000,'2025-09-04','2025-08-04','2025-09-05','All Docs Saved - Ethan,
Ethan,
Ask on Addison Longwood is $72-$73M or low $260K’s per door which is a 5% cap on the in-place rent roll with stabilized operations and a 5.25% Yr. 1.
 
The property is 95% occupied, never offered more than 1 month free concession (recently discontinued altogether), and has been achieving 60%-75%+ retention with 4%-5% increases on renewals. They experienced significant delays during construction with the city, which limited access into the property, so they were more focused on leasing velocity rather than pushing rents, which gives a strong mark to market opportunity for new ownership. The property also benefits from a minimal future supply pipeline with only 1 other deal delivering in 2025 and nothing else planned within a 3 mile radius.
 
The property sits in between the Lake Mary and Maitland office markets as well as 8 nationally ranked hospital systems totaling more than 3,200 beds. Proximity to these notable employment centers results in strong onsite demographics with average household incomes onsite of approx. $105K and virtually no historical bad debt issues.
 
Please let us know what questions you have as you review or if you would like to schedule a tour of the property.

We also have The Southerly at Orange City and Pointe at Palm Bay on the market as well, see below for deal summaries and links to the marketing websites.

The Southerly at Orange City – Orange City/DeLand Submarket, Daytona Beach MSA, Currently Marketing - Property Listing Website
•	2024 built, 298 units, highly-amenitized 3-story garden asset walkable to AdventHealth Bert Fish Hospital campus
•	Less than 15 minutes from the Lake Mary office market (10M SF of office)
•	89% occupied, 93% leased, $1,741 / $1.90 psf market rents
•	Guidance: $75-$76M, low $250K’s per door, 5.50% Yr. 1 tax adjusted cap rate
 
Pointe at Palm Bay – Palm Bay/Melbourne Submarket, Space Coast MSA – Currently Marketing - Property Listing Website

•	2024 built, 252 units, fully stabilized 3-story luxury garden asset adjacent to I-95 in Palm Bay, FL part of a 3 property Coastal Portfolio
•	Less than 10 minutes from Health First Palm Bay Hospital - $230M, 5-story tower expansion planned for 2026
•	Less than 15 minutes from the nation’s leading aerospace and defense contracting employers
•	94% occupied, 98% leased, $1,706 / $1.94 psf market rents
•	Guidance: $58M / $230K per door, 5.5% Yr. 1 tax adjusted cap rate',TRUE,TRUE,''),
('Promenade at Aventura Apartments','6 - Passed','Miami, FL',296,1994,NULL,NULL,NULL,'2025-09-03','2025-09-03','All Docs Saved - This will price around 440K-450K per unit.  Just under 5% cap adjusted for taxes.  Let us know when you would like to tour.',FALSE,TRUE,''),
('Amavida Marana','6 - Passed','Tucson, AZ',200,2024,300000,60000000,NULL,'2025-08-26','2025-09-03','Coming Soon / No Docs',FALSE,TRUE,''),
('Arbor Gates at Buckhead','6 - Passed','Atlanta, GA',303,1991,169966,51500000,NULL,'2025-08-18','2025-09-03','All Docs Saved - Ethan,

Arbor Gates has immediate upside. We are guiding to $170K per unit or $51.5 million (loan assumption) which is a low to mid 5% cap rate. 

•	Built in 1991 by Trammell Crow
•	Owned and operated by Executive Capital since 2004
•	Magnificent physical condition
•	Occupancy-focused rather than rent focused owner, with vacancy no greater than 7.3% in 10 years
•	Assumable $23 million Fannie loan at 3.65%, i/o for term due in 2030
•	CFO in mid to late September

Seller has asked that tours occur on Tuesdays and Thursdays so let us know when we can get you scheduled please.',TRUE,TRUE,''),
('Broadstone Peachtree Corners Apartments','6 - Passed','Atlanta, GA',295,2023,281355,83000000,NULL,'2025-08-28','2025-09-03','All Docs Saved -

Good afternoon, Ethan.  

Excited to get this one out into the market.  We are guiding to upper $80Ms or $280s to $290s/unit which equates to a FY1 5%+ cap.  A couple notes on the way we think of the opportunity:

-	25%+ discount to replacement Cost 
-	Fully stabilized with rents $550/unit lower compared to newest deliveries in the submarket (Solis Peachtree Corners)
-	Located in adjacent to 500-acre Atlanta Tech Park (10,000+ employees) 
-	< 1 Mile to 74-acre Peachtree Corners Town Center and The Forum (100+ shops/restaurants) 
-	Superior resident demographic profile with avg. HHI of $141k (6.2x income-to-rent ratio) 

Let me know when you want to go tour it with us.',TRUE,TRUE,''),
('The Crossings at Bramblewood Apartment Homes','6 - Passed','Richmond-Petersburg, VA',338,1976,144970,49000000,NULL,'2025-08-13','2025-09-03','All Docs Saved - Hey Guys —

Thanks for reaching out, please see below. We will be there next week.

Crossings at Bramblewood is a 338-unit apartment community located in the highly desirable Richmond–West submarket of Richmond, VA. Built in 1975, the property has been institutionally maintained and is currently 95% occupied. The community offers a mix of one-, two-, and three-bedroom apartments and townhomes ranging from 675 to 1,203 SF, with select units featuring in-home washers and dryers, stainless steel appliances, and upgraded finishes.
 
Pricing guidance is $49,010,000, or $145,000 per unit, representing a 5.40% cap rate on T-3 revenues and T-12 operating expenses with taxes adjusted upon sale. Crossings at Bramblewood presents investors with a compelling opportunity to acquire a well-located, value-add asset at a significant discount to replacement cost and recent trades in the Richmond market (e.g., Abbington Hills, 1975 vintage, $154KPU, sold October 2024). Comparable properties such as St. John’s Wood are currently achieving rents in the $1,287–$1,942/month/range -- approximately $375/month higher than Crossings’ current average.
 
Of the 338 units, 136 have been renovated by current ownership. The renovation scope includes Stainless Steel Appliances, White Shaker Cabinets, Laminate Countertops. This renovation achieves average rent premiums of $130/unit/month. The remaining 202 unrenovated units present a highly actionable value-add opportunity to introduce a higher-level renovation including hard-surface countertops to generate renovation premiums of $225/unit/month.
 
Crossings offers attractive assumable debt (outlined below):
 
Freddie Senior Loan:
•	3.34% Fixed-Rate
•	UPB: $24.23M
•	Origination: 6/30/20
•	Maturity: 7/1/30
•	Amortization: 7/1/25
 
Supplemental Indications:
•	$7,090,000
•	7.03%
 
Blended:
•	$31,320,000
•	4.16% Rate
•	63%+ LTV
 
Richmond’s rental market is forecasted to grow at an average annual rate of 3.10% between 2025 and 2029, driven by strong demand fundamentals and limited new supply—further enhancing the long-term investment outlook for Crossings at Bramblewood.',TRUE,TRUE,''),
('Everleigh Short Pump','6 - Passed','Richmond-Petersburg, VA',165,2021,387878,64000000,NULL,'2025-08-14','2025-09-03','All Docs Saved - Ethan,

Thanks for reaching out. Guiding to $64M+ ($388K/door), low-5 in-place cap rate.

Let me know if there is a good time for you to connect and discuss',TRUE,TRUE,''),
('The Pointe at Palm Bay','6 - Passed','Melbourne-Titusville-Palm Bay, FL',252,2023,230158,58000000,'2025-09-09','2025-07-25','2025-09-03','All Docs Saved - 3/3 in portfolio - Target pricing is Veranda at $265k per unit, Vero at $290k per unit and Palm Bay at $230k per unit.  Each asset is well positioned within its submarket. 

Let us know if you''d like to arrange a call to walk-through it all.  Looping in the team.',TRUE,TRUE,''),
('Mason Veranda','6 - Passed','Fort Pierce-Port St. Lucie, FL',300,2023,265000,79500000,'2025-09-09','2025-07-25','2025-09-03','All Docs Saved - 2/3 in portfolio - Target pricing is Veranda at $265k per unit, Vero at $290k per unit and Palm Bay at $230k per unit.  Each asset is well positioned within its submarket. 

Let us know if you''d like to arrange a call to walk-through it all.  Looping in the team.',TRUE,TRUE,''),
('Aspire Vero Beach','6 - Passed','',175,2023,291428,51000000,'2025-09-09','2025-07-25','2025-09-03','All Docs Saved - 1/3 in a portfolio - Target pricing is Veranda at $265k per unit, Vero at $290k per unit and Palm Bay at $230k per unit.  Each asset is well positioned within its submarket. 

Let us know if you''d like to arrange a call to walk-through it all.  Looping in the team.',TRUE,TRUE,''),
('The Queue','6 - Passed','Fort Lauderdale-Hollywood, FL',191,2017,329842,63000000,NULL,'2025-08-05','2025-09-03','All Docs Saved - $63MM',TRUE,TRUE,''),
('Nova Central Apartments','6 - Passed','Fort Lauderdale-Hollywood, FL',140,1996,285714,40000000,NULL,'2025-08-21','2025-09-03','All Docs Saved  -
Hi Ethan,

Guidance here is in the low $40m range which or just under $300k per door which is a 5.25-5.5% cap in place. This is nice 90s vintage concrete product with 9 foot ceilings.  There is also a light value add play to push rents another $100 or so.',TRUE,TRUE,''),
('5 Row Apartments','6 - Passed','Charlottesville, VA',128,2024,328125,42000000,NULL,'2025-08-20','2025-09-03','All Docs Saved - Ethan,
 
We are guiding to $42M, solving for a 5.6% cap in Yr1 (85% leased). Let me know if you have any additional questions.
 
Best,',TRUE,FALSE,''),
('Legacy at Walton Lakes','6 - Passed','Atlanta, GA',126,2009,95238,12000000,NULL,'2025-08-21','2025-09-03','All Docs Saved - Legacy at Walton Lakes (126 units, LIHTC)
Guidance
-	Price: $12MM (~$95K/unit)
-	Cap Rate: 5%-5.25% (Yr. 1)
-	Tax Exemption: Ability to partner with Housing Authority to obtain tax exemption to further increase yield

Investment Highlights
o	Built in 2009, newest affordable asset within a 3-mile radius
o	Significant Rental Upside: Rents are ±20% below max allowable rents (Walton Communities policy of capping rent increases at 5%)
o	Sticky Resident Base: Average tenure of 7+ years and 96%+ occupancy maintained since 2022',TRUE,FALSE,''),
('Walton Lakes','6 - Passed','Atlanta, GA',305,2009,190163,58000000,NULL,'2025-08-21','2025-09-03','All Docs Saved - Walton Lakes (305 units, market-rate)
Guidance
-	Price: $58MM (~$190K/unit)
-	Cap Rate: ~5.15% (T-12, tax-adjusted) and ~5.85% (Yr. 1, stabilized)
-	Financing: Optionality to assume HUD Financing at a 5.01% interest rate (35-year amortization) with ~33 years of term remaining

Investment Highlights
o	Immediate Rental Upside: ~50 legacy affordable tenants remaining on the rent roll that can be marked-to-market
o	Outstanding Performance: 95%+ occupancy, no concessions, and less than 2% bad debt
o	Positive Leverage Day 1: Financing costs of ±5.00% provide positive leverage out the gate
o	Proximity to Major Employers: Delta, Amazon, UPS, Hartsfield-Jackson Airport
o	High Quality Asset: Limited deferred maintenance with a full suite of amenities (pool, fitness center, clubhouse, BBQ areas, vegetable garden, etc.)',TRUE,FALSE,''),
('Enclave at Roswell','6 - Passed','Atlanta, GA',236,1985,182203,43000000,'2025-09-19','2025-08-14','2025-09-03','All Docs Saved - Upper $180k/door. Want to discuss?',TRUE,TRUE,''),
('Republic House','6 - Passed','Dallas-Fort Worth, TX',262,2000,240458,63000000,'2025-09-04','2025-07-23','2025-09-02','All Docs Saved - 
Seller is Grand Peaks and Rosewood. Hanover originally built it and very large units in a great school system. Would be tough to build again, particularly with the unit count. Money was put into it six or seven years ago but still more that can be done. Plus no washer dryers anywhere, flooring can be done in 2/3 of the units, etc. With the big units, guidance is low to mid-$240s/unit. 

 Are you guys interested in Cottages at the Realm as well? Noticed you signed a CA on that one.',TRUE,TRUE,''),
('Eastshore on Lake Carolyn Apartments','6 - Passed','Dallas-Fort Worth, TX',286,2019,244755,70000000,'2025-09-04','2025-07-23','2025-09-02','All Docs Saved - Low-mid $70m’s. 

We are also launching Promenade (its sister property). This will have guidance in the low $90m’s.',TRUE,TRUE,''),
('Margarite','6 - Passed','Washington, DC-MD-VA',260,2023,519230,135000000,NULL,'2025-08-22','2025-09-02','All Docs Saved - Ethan,

We are guiding to $135M total allocating $500K/unit to the residential and $5M to the retail at a 7.50% cap. It is a normalized in-place 5.25% blended cap rate on T3/T12 RE tax adjusted. The asset delivered in late 2023 and is 94% leased with steady growth, getting 5% increases on renewals in the month of August. Happy to get into it in more detail with you if that makes sense or schedule a tour. Let me know.',TRUE,TRUE,''),
('The Remy Apartments','6 - Passed','Fort Lauderdale-Hollywood, FL',271,2022,383763,104000000,NULL,'2025-08-20','2025-09-02','All Docs Saved - Ethan…target is $385k per unit. Thanks.',TRUE,TRUE,''),
('Capitol at Stonebriar Apartment Homes','6 - Passed','Dallas-Fort Worth, TX',424,2017,247641,105000000,'2025-09-08','2025-08-25','2025-09-02','All Docs Saved - $105 mm whisper strike, let us know if you need anything else.',TRUE,TRUE,''),
('Anthem Clearwater','6 - Passed','Tampa-St. Petersburg-Clearwater, FL',416,1975,187500,78000000,'2025-09-05','2025-08-05','2025-09-02','All Docs Saved 
Ethan, 

Hope all is well. We anticipate Anthem Clearwater trading in the $78M+ range, (5.9% Cap Rate range adjusted for taxes and insurance). This community presents an exceptional opportunity to acquire an infill central Pinellas County, 416-unit, garden-style community in Clearwater, Florida. The community has been meticulously maintained and has undergone significant capital improvements by current and former ownership. New ownership can leverage these enhancements to complete value-add unit renovations to 102 units and elevate all rents to market levels in the submarket. Please see below for property details and highlights. We will announce the CFO shortly.
 
Property Details: 
•	416-unit, 2-story, garden style community completed in 1975 (extensively renovated since 2015)
•	$19.2M ($46K+/unit) has been spent since 2015 on improving all aspects of the community including a 2018 built clubhouse 
•	Achieved average rent of $1,515/month 
•	52 two-story residential buildings in a low-density, park-like community spread across 21.11 acres
Value-Add Potential:
•	Proven value-add opportunity – 102 units are partially renovated and can be brought up to market rents 
•	All 416 units can be upgraded with select interior improvements, such as a stainless-steel appliance package to compete with similar renovation levels in the submarket
•	Renovation and mark-to-market premium with $449K+ potential income upside 
•	Ability to add a bulk cable/internet program netting $35/unit/month to ownership
Location:   
•	Centrally located in infill Pinellas County off Roosevelt Boulevard. This submarket has significant barriers to entry and limited opportunities for new multifamily developments due to the high replacement cost.
•	Only 20 minutes away from Tampa MSA major employment hubs – Westshore Tampa, Downtown St. Petersburg, and Clearwater
•	Minutes from TD SYNNEX (1,000+ Employees), St. Pete-Clearwater International Airport, Carillon Office Park (10,800+ Employees), Jabil, HSN HQ (3,000+ Employees), HCA Florida Largo Hospitals, and Morton Plant Hospital
•	20 Minutes from 35 miles of coastline including one of America’s top beaches – Clearwater Beach
•	Minutes from major retail shopping and dining destinations – Largo Mall, Clearwater Mall, & Tri-City Plaza',TRUE,TRUE,''),
('Latitude at Wescott Apartments','6 - Passed','Charleston-North Charleston, SC',290,2009,189655,55000000,'2025-08-26','2025-07-30','2025-09-02','All Docs Saved - Ethan – Helping out Kevin while he is on the road. 

Pricing guidance is low $190k/unit, which is a tax and insurance adjusted ~5.25% cap at 95% occupancy ear 1. Latitude at Wescott presents an outstanding opportunity to acquire a clean, institutionally maintained asset held by the same owner for the last 7+ years, well below replacement cost in an affluent growing Charleston submarket with avg HHI within 1 mile of $116K and in a class A-rated school district. Current ownership has renovated 76 units to top tier levels, allowing new ownership to continue those renovation efforts which are achieving $200 premiums.

Latitude at Wescott

Call for offers is August 26th. Let us know what questions you have as you dig in and if you would like to schedule a time to tour.

@Fallon, Alexa @ Charlotte Please double check that Ethan and Jay are on our distribution list.',TRUE,TRUE,''),
('Berkdale Apartments','6 - Passed','Washington, DC-MD-VA',184,1972,271739,50000000,'2025-08-26','2025-07-18','2025-09-02','All Docs Saved - Hey man – guidance is low $50MMs, ~5.75% in-place tax adjusted cap rate. Let us know if you have any questions as you review or would like to schedule a tour.',TRUE,TRUE,''),
('Oxford Apartments','6 - Passed','Phoenix-Mesa, AZ',432,2003,231481,100000000,NULL,'2025-08-22','2025-09-02','All Docs Saved  - $230k-240k',TRUE,TRUE,''),
('England Run North Apartments II','6 - Passed','Washington, DC-MD-VA',136,1999,NULL,NULL,'2025-08-27','2025-07-28','2025-08-28','All Docs Saved - Need this for other Parcel Seperate T12''s',TRUE,FALSE,''),
('England Run North Apartments I','6 - Passed','Washington, DC-MD-VA',204,1999,367647,75000000,'2025-08-27','2025-07-28','2025-08-28','All Docs Saved - 
-	Owned by Fairfield 
-	Spent 10M over the last 5 yrs
-	Guidance - $75MM
-	Low to mid 5’s Cap
-	Assumable debt, Matures 2031, Loan with CBRE Affordable',TRUE,TRUE,''),
('Aura Delray Beach','6 - Passed','West Palm Beach-Boca Raton, FL',292,2024,428082,125000000,'2025-03-18','2025-02-11','2025-08-28','All Docs Saved - Ethan…target on this is low $430’s per unit. Thanks.',TRUE,TRUE,''),
('LTD West Commerce','6 - Passed','Dallas-Fort Worth, TX',308,2018,198051,61000000,NULL,'2025-01-22','2025-08-27','All Docs Saved - We expect LTD West Commerce to trade in the $61M-$62M ($198k-$201k per unit) range. Built in 2018, this asset is a four-story wrap with 308 units and has 14,000 sf of commercial space on the ground floor. There is also a very attractive assumable loan that has a 3.57% interest rate and five years of term remaining.
 
LTD sits immediately west of Downtown Dallas in Trinity Groves which is a booming mixed-use development that has become a destination spot in DFW with over 20 restaurants, retail shops, and parks. Walkable from the property along the Trinity River, the city of Dallas has starting work on the $325M, Harold-Simmons Park. The park will span 250-acres and connect downtown to West and South Dallas and be filled with various experiences including biking trails, nature trails, canoeing/kayaking, dining, and more.
 
Within a 10-minute drive of the asset you have major employment drivers inside the Dallas CBD (135k+ employees) including AT&T, Comerica, Deloitte, Goldman Sachs, JP Morgan, etc.
 
A CFO date has not been set yet, but will likely take place in mid-to-late February. Please let us know if you have any questions or would like to come out for a property tour.',TRUE,TRUE,''),
('Waterford Place','6 - Passed','Greensboro--Winston-Salem--High Point, NC',240,1997,204166,49000000,'2025-08-26','2025-07-30','2025-08-26','All Docs Saved - $49MM',TRUE,TRUE,''),
('The Avalon','6 - Passed','Charlotte-Gastonia-Rock Hill, NC-SC',240,1999,170833,41000000,'2025-08-26','2025-07-28','2025-08-26','All Docs Saved - Ethan – We are guiding $170k - $180k/unit which reflects a 5.15% - 5.5% cap (insurance and tax adjusted) on T3 numbers and a high teens to 20% IRR. Currently 21 units are upgraded and achieving $215+ premiums, providing new ownership with a great opportunity to continue a successful renovation plan on the remainder of the property. The asset includes a great unit mix as well with over two thirds being 2BR and 3BR units averaging over 1,000 SF. 
 
The Avalon sits in East Charlotte, a submarket that has seen very little market rate delivery fueling strong rent growth projections of 4.85% per year through 2030. The product and amenity set on The Avalon is best in class as well, giving new ownership a great starting point to build from.  
 
Deal room: https://multifamily.cushwake.com/Listings/31621
 
CFO: August 25, 2026
 
Let us know if you have any questions. We are starting tours next week.',TRUE,TRUE,''),
('Tapestry Tyvola','6 - Passed','Charlotte-Gastonia-Rock Hill, NC-SC',297,2022,222222,66000000,'2025-08-26','2025-07-15','2025-08-26','All Docs Saved - Guidance is $225k/door range. 5% in place. Really good basis below replacement cost for HDS product. It was on the market early last year with guidance in the mid $250ks. Neighboring deals are coming to market in LoSo and South End for $350k/door and $380k/door
First Floor ceiling heights range from 12’ to 20’ high. Other levels are all 10’.
Lots of opportunity to boost NOI including bulk WiFi, fenced yards, and smart home/tech package.',TRUE,TRUE,''),
('Madison Wakefield','6 - Passed','Raleigh-Durham-Chapel Hill, NC',216,2023,222222,48000000,'2025-08-20','2025-07-09','2025-08-25','All Docs Saved - New Deal right across the street from Columns - 225k-230k/unit`
Update 8/18: offer 44M and see what happens',TRUE,TRUE,''),
('Bell Kennesaw Mountain Apartments','6 - Passed','Atlanta, GA',450,2001,244444,110000000,NULL,'2025-08-15','2025-08-21','All Docs Saved - Hey Ethan – 

Price guidance is mid-upper $240ks/unit, or $110M+, which is a low-5% in-place. Let us know if you want to tour. 
 
•	High-quality physical product: 450 units built in 2001 with 9’ ceilings and 48 rare townhome units 
•	95%+ occupied despite not having a clubhouse for two years – oversized clubhouse rebuilt new 
•	Nearly 70% of the units are ready for renovation, with nearby comps providing $400++ rent headroom 
•	Zoned for “A” rated schools 
•	The growth of Kennesaw State University (48,000 students) has been a catalyst for the area flourishing
•	Whole Foods and Publix-anchored shopping centers located within a mile of the property 
•	Immediate access to I-75 delivers convenient connectivity to every major employment node of the northern suburbs
•	Despite Kennesaw’s growth, only one conventional multifamily property currently under construction (229 units)',TRUE,TRUE,''),
('Perimeter Gardens at Georgetown','6 - Passed','Atlanta, GA',245,2006,224489,55000000,'2025-08-19','2025-07-29','2025-08-19','All Docs Saved, No OM - 
Ethan,

Thanks for reaching out.

Pricing guidance is $55M ($225K/unit):

•	5.8% Year 1 Cap Rate including renovations to 1/3 of units and 50% penetration of other income upside
•	4.7% Trailing Cap Rate T1 income with tax-adjusted/normalized expenses

Post-renovation is a mid-7% Year 3 Cap Rate assuming a ~$13K/unit spend and ~$300 blended premium—taking rents to $1,887 ($1.97 PSF).

Very clean asset with renovation opportunity on 100% of units. AMLI built product which Sentinel has owned and meticulously maintained for the past 8 years.

In-place rents are $1,600 ($1.67 PSF) and other income is well below-market. Clear income upside with headroom to comps and opportunity to run more efficiently from an expense standpoint.

The current resident base has lived at the Perimeter Gardens for an average of ~4 years and the property has retained 74% of renewals YTD with ~2% increases.

The property has a great on-site feel with mature landscaping and is over-amenitized with two pools for 245 units.

Ideal position between two newly-built $1M+ single family neighborhoods, brand new Emory Dunwoody medical office, and greenspace/parks.

Superior access to grocers, retail, and restaurants on the main thoroughfare through Dunwoody and quick connectivity to employment/lifestyle options in Central Perimeter, Pill Hill, and Chamblee/Brookhaven.

CFO will be on August 19th.

Let us know when you can discuss/tour.',TRUE,TRUE,''),
('Afton Palms','6 - Passed','Orlando, FL',352,2024,269886,95000000,'2025-05-07','2025-04-04','2025-08-19','All Docs Saved -Ethan,

Ask price on Afton Palms is $95M, $270K, which is a low 5% on their current leased rents, adjusted for stabilized operations and post-sale taxes. Using the recent rents that the property has been achieving, the cap rate improves to between a 5.25-5.4%.

Afton Palms is 4-story elevator serviced garden property with a great location in the Lake Mary submarket, less than 10 minutes from 2 hospitals and over 8M SF of office space. The property has had a fantastic lease-up despite having 2 other projects that were also in lease-up at the same time and is on track to be stabilized in less than 12 months from delivering first units.

Additionally, the Lake Mary submarket has limited supply, with only 1 project that will be delivering in 2025 and nothing else under construction within 3 miles of the property. The limited supply, combined with a strong on-site demographic profile (Avg HH Incomes of +/- $120K on-site), should give a new owner the opportunity to push rents once stabilized, which is reflected in the property''s recent leasing being at 3-4% increases over the average in-place rents.

Let us know what questions you have as you review or if you''d like to schedule a tour.',TRUE,TRUE,''),
('The Southerly at Orange City','6 - Passed','DaytonaBeach, FL',298,2024,251677,75000000,'2025-09-03','2025-07-22','2025-08-18','All Docs Saved -Ethan,

Ask is $75-76M, low $250k''s per door, which is a 5.25% on their current rent roll with stabilized operations and  close to a 5.5% year 1 using 3rd party projected rent growth.

It''s a really nice deal in Orange City, which is a secondary submarket less than 20 minutes north of the Lake Mary office market in Orlando. The property was in lease-up at the same time as two other projects, but moving forward there is nothing under construction and nothing currently planned in the submarket so there should be a lot of room to run on the rents moving forward for the next few years.

Let us know if you have any questions as you review or if you would like to tour.',TRUE,TRUE,''),
('Legacy at West Cobb','6 - Passed','Atlanta, GA',395,1970,149367,59000000,NULL,'2025-07-29','2025-08-18','All Docs Saved - Ethan,

Thanks for your interest in Legacy at West Cobb.  Here’s some additional color.

Legacy is 395 units built in 1970 in Marietta.  We expect it to trade around $150K/unit, which is north of a 7 cap.  Legacy finalized the Qualified Contract process in November of 2024 and subsequently entered the 3-year decontrol period.  Since November, EGI has already improved by 12%, and a new owner can continue that trend with the continued conversion to a fully market rate asset.

The link below will provide access to our doc center where the OM and latest financials are available for download.  Let us know if you have any questions and when you would like to schedule a tour.  We look forward to your feedback.',TRUE,TRUE,''),
('505 West','6 - Passed','Phoenix-Mesa, AZ',334,1981,209580,70000000,'2025-08-20','2025-07-15','2025-08-18','All Docs Saved - 
Thank you for your interest in 505 West, a 334-unit, value-add multifamily community located in the high-demand Tempe submarket of Metro Phoenix. (CA: RCM Deal Room Link). 505 West presents an exceptional opportunity to acquire a stabilized asset with immediate operational and physical upside, supported by favorable submarket fundamentals and long-term economic drivers.
•	Guidance: $70,000,000 ($209,581/unit)
•	Tours: Please reach out to Emily Soto to schedule onsite tours
•	Financing: Please reach out Brandon Harrington and Bryan Mummaw to discuss financing options
•	Call for Offers: To Be Announced
 
Deal Highlights: Stabilized, High-Performing Value-Add Opportunity in Prime Tempe Location
•	Institutionally Owned and Professionally Managed – 505 West has been operated by an experienced institutional owner, ensuring strong historical performance, well-maintained operations, and a seamless transition for new ownership
•	Classic value-add profile with 55% classic interiors and 51% of units lacking in-unit washers/dryers — renovations are achieving up to $290/month rent premiums with 31% return on cost (interiors) and 21% (W/D install)
•	In-place rents trail the competitive submarket by ~$240/month, providing immediate mark-to-market upside
•	$4.7M in completed capital improvements including upgraded pool, clubhouse, leasing center, roofs, HVAC, landscaping, paint, and more — future capital needs are minimal
•	Offers a compelling cost advantage over homeownership: average monthly rent of $1,386 vs. ~$3,300/month to own, reinforcing long-term rental demand
•	Favorable supply/demand imbalance: only three multifamily projects under construction within a 3-mile radius; Tempe’s population projected to grow 14% by 2030
•	Diverse unit mix (1-, 2-, and 3-bedrooms) with average unit size of 856 SF, catering to a broad renter base including families, young professionals, and workforce renters
•	Additional operational upside through washer/dryer installations, parking revenue, and implementation of tech, amenity, and pet packages
•	Anchored by major regional employers including Arizona State University (75,000+ students), Novus Innovation Corridor (24,000+ jobs), and Discovery Business Campus
•	Strong surrounding demographics: average household income of $90,317 within a 3-mile radius
________________________________________
Location Highlights: Highly Connected Urban Infill Location Near Major Job Hubs
•	Immediate access to I-10 and US-60, offering direct connectivity to Downtown Phoenix, Sky Harbor Airport, Chandler Tech Corridor, and broader East Valley employment nodes
•	Strategically positioned near major educational, technology, and healthcare anchors fueling steady renter demand
•	Excellent walkability and proximity to retail, dining, and daily needs services in central Tempe
________________________________________
Major Economic Drivers (within 5–20 minutes of the property)
•	Arizona State University (75,000+ students)
•	Novus Innovation Corridor (24,000+ jobs projected)
•	Mill Avenue Entertainment District 
•	Discovery Business Campus
•	The Watermark Tempe
•	Sky Harbor International Airport
•	Downtown Phoenix
•	Price Corridor / Chandler Tech Corridor (43,000+ jobs / 13,600+ jobs)
•	Banner Health, Honeywell, ADP, and other Fortune 500 employers',TRUE,TRUE,''),
('Cascades at the Hammocks','6 - Passed','Miami, FL',264,1988,299242,79000000,'2025-08-20','2025-07-16','2025-08-18','All Docs Saved - 
Update 8/13 - Ethan,

Just FYI we’ve dropped guidance on Cascades to somewhere north of $300k per door. 

To be clear that doesn’t mean we think the deal will trade around $300k per door, but there is some flexibility somewhere between $300k per door and the original ask of $325k per door.

Please don’t hesitate to reach out if you have any questions or need anything else ahead of the bid deadline next week.

Hi Ethan,

Guidance on Cascades is around $325k per door which works out to a 5.5% in-place cap with reassessed taxes and insurance at $1,500 per unit based on a quote from Lockton in the deal room.

Very attractive unit mix with nearly ¾ two- or three-bedroom floorplans getting strong rents on the back of recent interior and exterior upgrades.

Current ownership (Grand Peaks) invested nearly $4 million in capital since 2021 including brand new roofs, and Kendall is an awesome suburban rental market with A-rated public elementary and middle schools zoned for Cascades.

There is also accretive assumable debt available maturing in 2028 with a 4.5% rate and full-term interest-only remaining.

Let us know if you’d like to discuss further or arrange a tour.',TRUE,TRUE,''),
('Pallas at Pike & Rose','6 - Passed','Washington, DC-MD-VA',319,2015,376175,120000000,'2025-09-04','2025-07-28','2025-08-18','All Docs Saved  - Hi Ethan,

Have any availability to connect on this and some of the other deals we have out? 

Guidance is low $120M, upper $300k/unit and ~5.0% in-place. The data room will be made available later this week. 

Some highlights below:
•	Flagship Pike & Rose high-rise priced 30%+ below replacement cost with zero new supply in the broader submarket 
•	Compelling Rent Growth – 4–6%+ lease trade-outs and over the past 90 days
•	Pike & Rose Mixed-Use Premium: Immediate access to upscale retail, high-end dining & 100% leased Class-A offices driving consistent demand
•	Mature & Affluent Demographics – Avg. household incomes are 1.2x higher than broader North Bethesda market (~$198k)
•	Top National School District – A+ rated North Bethesda school system driving 
•	Transit-Oriented Location – Strategically positioned adjacent to North Bethesda Metro, I-270 Tech Corridor, & Capital Beltway',TRUE,TRUE,''),
('The Lights at Northwinds','6 - Passed','Atlanta, GA',140,2022,392857,55000000,'2025-08-14','2025-07-07','2025-08-18','All Docs Saved - Ethan,

Price guidance is mid-$50Ms.  A few notes on the opportunity:
 
•	Lights at Northwinds is the residential anchor of the Northwinds Summit mixed-use development in Alpharetta
•	Located along Alpha Loop, Alpharetta’s beltline, connecting the property to Downtown Alpharetta and Avalon
•	Proximate to 13.5 MSF of Class A office and 900 tech employers
•	The structure-parked midrise includes 140 units built in 2022 by The Worthing Companies, featuring 10-foot ceilings and modern finishes 
•	9k SF of ground floor retail is a separate condo and not part of this offering
•	The property is 97% occupied, 99% leased, and recent 60-day trade-outs have gains of $90+ (+4%)
•	Significant headroom still exists ($400 on average) to other Class A Alpharetta comps
 
A CFO date has not been established but I would anticipate it for early August.  Would you like to schedule a time to tour the asset with us?',TRUE,TRUE,''),
('McKinney Village Apartments','6 - Passed','Dallas-Fort Worth, TX',245,2017,200000,49000000,'2025-08-12','2025-07-10','2025-08-14','All Docs Saved - $49MM',TRUE,TRUE,''),
('Copper Mill Apartments','6 - Passed','Richmond-Petersburg, VA',192,1987,218750,42000000,'2025-08-13','2025-07-16','2025-08-14','All Docs Saved - Hey Ethan - This one is pretty interesting in that while there is value-add upside, operationally, there is even more. Not a brokers spin blaming operations, but as alluded to below, they haven’t had a dedicated manager since they bought the property. Can explain more over a call. 
•	Guidance: We''re aiming for $42M, reflecting a 5.25% cap rate on tax-adjusted trailing figures, but closer to a 6% cap rate in year one by addressing operational challenges, particularly vacancy issues due to the absence of an on-site property manager.
•	Location and Potential: Copper Mill is ideally located in Richmond''s West End submarket, right off Broad Street, the main route connecting Short Pump to Downtown. There''s a high demand for multifamily, as evidenced by competing properties with occupancy rates of 95% or higher.
o	Although 141 of the 192 units have been renovated, they vary in quality and don''t meet new renter expectations seen in comparable properties. We recommend modern renovations (stainless steel appliances, granite countertops, LVT flooring, updated lighting and fixtures) to capture the $200-$300 rent gap compared to similar assets.
•	Additional Deal Highlights:
o	Located in strong school district, with ratings from A- to A+ from elementary to high school.
o	Local home sales support ongoing rent growth, with prices ranging from $530k to $610k within a 1.5-mile radius.
o	Strategically located on Broad Street, Copper Mill is equidistant between Short Pump and downtown Richmond. It''s just 2 minutes from Costco, Publix, Lowes, and Kroger, and 15 minutes from Short Pump Town Center and 10 minutes from Short Pump Village (Target, Whole Foods, Trader Joe''s, Home Depot, etc.), offering convenient access to retail options that today''s renters anticipate 

Let me know what day this week you’re free to catch up.',TRUE,TRUE,''),
('The Quincy at Kierland','6 - Passed','Phoenix-Mesa, AZ',266,2024,458646,122000000,'2025-08-13','2025-07-15','2025-08-14','All Docs Saved  - $460s per unit.',TRUE,TRUE,''),
('M2 at Millenia Apartments','6 - Passed','Orlando, FL',403,2019,272952,110000000,'2024-10-16','2024-09-26','2025-08-14','All Docs Saved - Pricing guidance on M2 at Millenia is $110M (~273k per door or $290 PSF). Also built in 2019, comprises 403-units plus 4,216 SF of ground-floor retail, and sits at 97% occupancy. M2 sits 50-yards from the Mall at Millenia, one of the top 10 most profitable retail destinations in the US. We are insulated from high new supply pockets and have quick access to I-4 and Orlando’s top employers.',TRUE,TRUE,''),
('Hayden Park Apartments','6 - Passed','Phoenix-Mesa, AZ',182,1985,258241,47000000,'2025-08-19','2025-07-09','2025-08-11','All Docs Saved - 
Jay,
Thank you for your interest in Hayden Park.  We anticipate pricing to be in the $260K per unit range which is an approximate 5.0% cap rate on current in-place income.  Some key details of the Hayden Park offering include:
 
•	Rare Scottsdale location / value – add opportunity
•	Same ownership history since 1999
•	Since 2022, approximately 25% of the units have undergone a significant renovation program resulting in an average rent premium of over $300 per month
•	46 units at Hayden Park are unique single level/casita style units
 
Let us know if you would like to schedule a call to discuss Hayden Park in more detail or if you would like to arrange a property tour.  
Thanks',TRUE,TRUE,''),
('Gables Dupont Circle','6 - Passed','Washington, DC-MD-VA',82,1998,597560,49000000,'2025-08-27','2025-07-15','2025-08-11','All Docs Saved - Hi Ethan, we’re guiding to a $49M which is an in-place, tax-adjusted 5.25% cap. NOI has grown 13%+ in T3/T12 and we’re at 97% occupancy.  We''re seeing excellent performance with continued rental increases and low turnover (one unit in the next 30 days, three more in the following 30 days). The location is irreplaceable situated in the heart of Dupont Circle with high barriers to entry and insulated from new supply. 

Let us know if we can schedule a call to discuss in more detail and/or arrange to tour you through this exceptional asset.',TRUE,TRUE,''),
('Country Brook Apartments','6 - Passed','Phoenix-Mesa, AZ',396,1986,277777,110000000,NULL,'2025-04-24','2025-08-07','All Docs Saved - Country Brooke
-	110M guidance
-	1992 built
-	Chandler, next to Intel campus',TRUE,TRUE,''),
('Bluewater Apartments at Bolton’s Landing','6 - Passed','Charleston-North Charleston, SC',350,2018,250000,87500000,'2025-08-05','2024-05-29','2025-08-06','All Docs Saved -


Ethan, Thanks for reaching out. We are excited about Bluewater!  The property is a solid performer,  with clear rent growth and minimal concessions.  
There is also proven and well-supported value-add lift here as the West Ashley thesis continues to impress.  
 
Both the neighborhood and submarket continue to see increasing incomes and home prices, with a deepening renter pool, but zero conventional new supply currently under-construction.
 
We anticipate competitive initial pricing in the upper $80Ms, or $250Ks per unit.






Jay!  Absolutely. RE Shadetree – we are under agreement. We awarded in the upper $240Ks .  on Bluewater, it’s a great opportunity candidly.
Below are a few key points, along with pricing guidance:
 
•	Large average unit size (1,062 SF, >60% 2BR & 3BR Floorplans) embedded in Master Planned Community pair well with affluent neighborhood level demos (Avg. HHI ~$113K) and rapid home value appreciation (+24% since 2023)
•	Solid submarket rental growth (6.5% annual avg. since 2022) with limited supply pipeline (<500 units currently under-construction)
•	Strong leasing trends on-site (>95% sustained occupancy, >13% NRI growth over T-12) and material headroom of $400+ to proximate brand new construction support value-add potential
o	75% of units eligible for full suite of upgrades from current base-level interiors, at $150+ target premiums 
 
We anticipate pricing in the Upper $80Ms or high $240Ks - $250K± per unit.  A call for offers date has not been set but is likely to be the third week of June.',TRUE,TRUE,''),
('Grand Central','6 - Passed','Fort Myers-Cape Coral, FL',280,2019,250000,70000000,'2025-08-07','2025-07-09','2025-08-06','All Docs Saved  - Guidance is $70M/$250k/unit, stabilized 6 cap with adjusted taxes. The property has a TIF through 2031, roughly $400,000/yr in tax abatement. The property would qualify for the Live Local program which can be stacked with the TIF. The seller implemented the Real Advice PP Allocation strategy at acquisition and can be stacked with TIF and Live Local. With these programs that would take you north of 6.5 cap. Great concreate block deal in good location on US41 and Colonial Blvd (85,000 cpd).',TRUE,TRUE,''),
('The Rocca','6 - Passed','Atlanta, GA',314,2002,270700,85000000,'2025-08-05','2025-07-08','2025-08-05','All Docs Saved - Ethan,

Appreciate you reaching out.

Pricing guidance is $85M ($270K/unit) or $234 PSF.

This is a 5.69% Year 1 Cap Rate (including renovations to 1/3 of units) and a 4.72% Trailing Cap Rate (T3 income with tax-adjusted/normalized expenses).

Significant headroom opportunity with below-market in-place rents of $1,870 ($1.63 PSF) but above average unit sizes of 1,157 SF.

Truly unique product built in 2014 (phase II, 284 units) and 2002 (phase I, 80 units). Institutionally owned and maintained by MetLife since inception.

Rare opportunity to renovate 96% of units. Only 14 units have been upgraded, which generated rent premiums up to $450. 

Post-renovation, there is opportunity to achieve a 7.25% Year 3 Cap Rate assuming a ~$25K/unit spend and $420 blended rent premium—taking rents to $1.98 PSF.

The Rocca is in Atlanta''s most affluent single-family neighborhood ($175K HHI within 1 mile) and is one of only two properties developed in West Paces since 1992.

Let us know when you''re available to discuss and/or tour.',TRUE,TRUE,''),
('Enclave at Potomac Club Apartments','6 - Passed','Washington, DC-MD-VA',406,2013,344827,140000000,NULL,'2025-07-17','2025-08-04','All Docs Saved - Enclave at Potomac Club: 
$140mm --- 5.5% Cap Rate',TRUE,TRUE,''),
('VY Reston Heights','6 - Passed','Washington, DC-MD-VA',385,2018,376623,145000000,NULL,'2025-07-15','2025-08-04','All Docs Saved - VY Reston:
$145mm --- 5.25% Cap Rate',TRUE,FALSE,''),
('909 Flats Apartments','6 - Passed','Nashville, TN',232,2017,275862,64000000,'2025-08-05','2025-06-09','2025-08-04','All Docs Saved - 
Thanks for the note! Targeting Mid-$60M, which is +/- $280k per door at a mid-upper 4% cap in-place.
Let’s catch up this week.',TRUE,TRUE,''),
('Reserve at White Rock Apartments','6 - Passed','Dallas-Fort Worth, TX',312,1999,198717,62000000,'2025-08-05','2025-07-31','2025-08-04','All Docs Saved - AMAC is the seller on these. They acquired them separately and have combined operations. You could break them up later. Lots of value add opportunity. They aren’t even on revenue management. About 30% of the units are townhomes as well. Guidance is roughly $200K-$205k per unit blended for the two assets, which is a low 5% cap in-place.',TRUE,TRUE,''),
('Trails of White Rock Apartments','6 - Passed','Dallas-Fort Worth, TX',276,2000,199275,55000000,'2025-08-05','2025-07-31','2025-08-04','All Docs Saved - AMAC is the seller on these. They acquired them separately and have combined operations. You could break them up later. Lots of value add opportunity. They aren’t even on revenue management. About 30% of the units are townhomes as well. Guidance is roughly $200K-$205k per unit blended for the two assets, which is a low 5% cap in-place.',TRUE,TRUE,''),
('Hawkins Press','6 - Passed','Charlotte-Gastonia-Rock Hill, NC-SC',426,2024,387323,165000000,NULL,'2025-07-23','2025-08-04','All Docs Saved - High 300''s per door. High-4 cap in-place with fully loaded taxes/Mid-5 cap with brownfields abated taxes.',TRUE,TRUE,''),
('The Crossings at Union','6 - Passed','Newark, NJ',126,1945,234126,29500000,NULL,'2025-07-28','2025-08-04','All Docs Saved - Hey Ethan,

Guidance here is $29.5mm which is a little over a 6% cap going in.  The property has seen significant capex including individual energy efficient HVAC systems recently installed in every unit, pushing that expense onto the tenants. They also started a 35 year HUD loan process which could be taken over at $21.5mm and 5.75% rate. It is not required to take over this loan but rather an option if it fits the box for you.',TRUE,TRUE,''),
('Gables Midtown','6 - Passed','Atlanta, GA',345,2009,231884,80000000,'2025-07-29','2025-06-18','2025-07-31','All Docs Saved - •	Low $230K per unit',TRUE,TRUE,''),
('Hampton West Apartments','6 - Passed','Charleston-North Charleston, SC',41,2002,NULL,NULL,NULL,'2025-07-30','2025-07-30','Coming Soon',FALSE,TRUE,''),
('Daniel Island Village','6 - Passed','Charleston-North Charleston, SC',283,2009,289752,82000000,'2024-08-15','2024-07-22','2025-07-25','All Docs saved- $82M here.

5.25% ish on in-place rent, tax adjusted with normalized controllable expenses and other income.

High controllables in the T-12 due to a fair amount of additional expense tied to a robust interior reno program which wrapped up in May (a few months ago). The renos took 1-2 months to turn per unit depending on unit size (3 Bds took just under 2 months, and 1 BDs were usually 30-35 days). So there is elevated vacancy in our T-12 and elevated controllables as well – over $6,000 per unit – I think this should be run closer to $5,500 per unit which is still high.

T-12 payroll is $2,318 per unit (283 units- I think can be down significantly more efficiently) – they over staffed due to the reno – can we run 3 in / 4 out – should be about $500K per unit of savings

T-12 R&M is $886 per unit – some reno costs included here – will be much less going forward – should be about $500 - $600

T-12 CS is ~$1,100 per unit – should be $200 - $300 per unit less

Utility costs are going down as well - we have overstated “vacant electric” due to all the renos in the T-12   

When you normalize these items it’s a 5.25% tax adjusted in place cap',TRUE,TRUE,''),
('Southpoint Reserve At Stoney Creek Apartments','6 - Passed','Washington, DC-MD-VA',156,1985,230769,36000000,'2025-07-23','2025-06-26','2025-07-25','All Docs Saved - 36M 6% Cap',TRUE,TRUE,''),
('Brewers Block','6 - Passed','Pittsburgh, PA',377,2023,305039,115000000,'2025-07-23','2025-07-16','2025-07-23','All Docs Saved - Hi Ethan – we’re offering guidance of $115M ($305k/unit), which works out to an in-place 5.5% cap rate (6.0% Year 1).
 
Let us know if you have any questions as you work through your review.',TRUE,TRUE,''),
('Scottsdale on Main Apartments','6 - Passed','Phoenix-Mesa, AZ',119,2024,554621,66000000,'2025-07-23','2025-06-13','2025-07-23','All Docs Saved - 66M',TRUE,TRUE,''),
('1105 Town Brookhaven Apartments','6 - Passed','Atlanta, GA',299,2014,287625,86000000,'2025-07-22','2025-05-01','2025-07-22','All Docs Saved - Hey Ethan, 

Thank you for your interest in 1105 Town Brookhaven, a truly exceptional opportunity to own a 2015 vintage property located within a prominent MXU development. Our price guidance is about $290,000s/unit (mid to upper $80,000,000) which equates to a low 5% cap rate on in place NOI and about a 30% discount to replacement cost.

Some of the key investment highlights are as follows:
•	Compelling Brookhaven location within a 460K SF Costco/Publix anchored mixed-use development
•	Excellent property and area demographics in “A-rated” school district ($211K HHI, $878K AHV within 1-mile radius) 
•	Core plus opportunity with proven value-add upside (64 renovated units receiving +$375 premium) 
•	No new apartment supply in Brookhaven (2 properties in lease-up with rents $600+ higher)

CFO will likely be in mid-July and will keep you updated once the date is set. 

Let me know if you’d like to schedule a tour.',TRUE,TRUE,''),
('Overture Cary','6 - Passed','Raleigh-Durham-Chapel Hill, NC',189,2021,402116,76000000,'2025-07-22','2025-07-08','2025-07-22','55+ All Docs Saved - Portfolio: $187M total, which is a high 4% on in-place and low 5-5.3% year 1
 
Cary: $76M
Chapel Hill: $57M
Hamlin: $54M',TRUE,TRUE,''),
('Overture Chapel Hill','6 - Passed','Raleigh-Durham-Chapel Hill, NC',184,2020,309782,57000000,'2025-07-22','2025-07-08','2025-07-22','55+ All Docs Saved - Portfolio: $187M total, which is a high 4% on in-place and low 5-5.3% year 1
 
Cary: $76M
Chapel Hill: $57M
Hamlin: $54M',TRUE,TRUE,''),
('Alexan Mills 50','6 - Passed','Orlando, FL',245,2024,285714,70000000,'2025-07-29','2025-06-18','2025-07-22','All Docs Saved - Hey Ethan - Alexan Mills 50 is a one-of-a-kind. Amazing infill location with very high barriers to entry. Walk score of 93 (walker’s paradise), drive-by of nearly 50,000 cars/day. Strong demos with avg resident income around $134,000. The Mills 50 neighborhood has become the epicenter of top dining in Orlando, and this pocket has 25 Michelin and James Beard awarded restaurants (more than virtually any other neighborhood in Florida).  Surrounded by Baldwin Park, Winter Park, Thornton Park and College Park – the most affluent infill parts of Orlando. Within 10 mins of 100,000 jobs, including the main AdventHealth and Orlando Health hospital campuses. Really unique amenities and thoughtful A+ finishes…also have 15 live/work units.  The list goes on and on…

Guidance around $70-$71M range.  New stabilized product available below replacement with room to run on the rents.  Would be an awesome addition to your portfolio.

Let us know if you’d like to discuss or schedule a tour.',TRUE,TRUE,''),
('Overture Hamlin','6 - Passed','Orlando, FL',180,2021,300000,54000000,'2025-07-22','2025-07-08','2025-07-22','All docs Saved - Portfolio: $187M total, which is a high 4% on in-place and low 5-5.3% year 1
 
Cary: $76M
Chapel Hill: $57M
Hamlin: $54M',TRUE,TRUE,''),
('Milano Lakes Apartments','6 - Passed','Naples, FL',296,2019,358108,106000000,'2025-08-14','2024-05-15','2025-07-22','all docs saved
JBM Pricing - 

Newmark Pricing from last yr -Target pricing is $106mm. Would you like to arrange a time to discuss or set up a property tour?  Offers will be due in about a month.',TRUE,TRUE,''),
('Lattitude34 Greenville','6 - Passed','Greenville-Spartanburg-Anderson, SC',96,2023,270833,26000000,NULL,'2025-07-07','2025-07-22','All Docs Saved - Hi Ethan - We are guiding to $25.9M ($270k per unit), which shakes out to ~5.10% in-place cap rate (T3 vac & tax adj.) & a 5.70% tax adj. year one cap rate.
 
The property consists of 3-, 4-, and 5-bedroom individually-platted, detached single-family homes and townhomes, each featuring 1- and 2-car garages. L’Attitude 34 Greenville is located less than 20-minutes away from DT Greenville and offers seamless connectivity to Greenville MSA employers. Additionally, the property presents a significant discount to retail with homes selling for an average of $453,000 in the immediate area. 
 
L’Attitude 34 Greenville Deal Room
 
Let us know if you would like to discuss further!',TRUE,TRUE,''),
('Waverly Place','6 - Passed','Charleston-North Charleston, SC',276,1986,144927,40000000,NULL,'2025-07-21','2025-07-22','All Docs Saved - Hey there Ethan

Guidance is $145K - $150K per unit here, $40-$41.5M… 
Low 5% cap in place / mid 5% yr 1

Let us know if you have any questions.',FALSE,TRUE,''),
('Series at Riverview Landing Apartments','6 - Passed','Atlanta, GA',270,2022,259259,70000000,NULL,'2025-06-05','2025-07-22','All Docs Saved No OM - Ethan,
 
Appreciate you reaching out. 
 
Series at Riverview Landing is a rare opportunity to own a newly built asset along the Chattahoochee River – 1 of 2 properties in Atlanta with riverfront access and views.
 
Total Pricing is $70M ($260K/Unit), which includes ~8K SF of fully leased retail and $1.8M of Brownfield Tax Savings. 
 
Multifamily Pricing is ~$65M ($243K/Unit), which is a 5.91% April T1 fully tax-adjusted cap rate. 
 
The seller’s preference is to leave equity in the deal and is open to a variety of structures.
 
Feel free to reach out to us with any other questions.',TRUE,TRUE,''),
('Everleigh Duluth','6 - Passed','Atlanta, GA',180,2023,300000,54000000,NULL,'2025-07-09','2025-07-22','Greystar 55+ All Docs Saved - Ethan, 

on Everleigh Duluth is mid-$50M’s or low $300K’s/unit (which will translate to a low-to-mid 5% cap Year 1). This is a well-executed deal that’s walkable to historic, downtown Duluth (300K SF of shops/restaurants). If you consider the strong demographic/single-family profile and high barriers-to-entry, there’s a compelling investment thesis. I’d be happy to discuss live in more detail at your convenience.',TRUE,TRUE,''),
('Stacks on Main','6 - Passed','Nashville, TN',268,2017,261194,70000000,'2025-07-21','2025-06-18','2025-07-22','All Docs Saved - Low 70ms',TRUE,TRUE,''),
('The Batley','6 - Passed','Washington, DC-MD-VA',432,2019,381944,165000000,NULL,'2025-03-20','2025-07-21','Tracking Purposes - Coming Soon - 165M',TRUE,TRUE,''),
('Eden at Lakeview','6 - Passed','Atlanta, GA',255,2024,450980,115000000,NULL,'2025-04-15','2025-07-17','All Docs Saved - Ethan,

Pricing guidance is $115M ($450k/unit) which is a 5.55% All Cash Yield; inclusive of ~12k SF of Retail (all 4 bays spoken for) and a 10-Year Tax Abatement.

Eden at Lakeview is an exceptional asset in Alpharetta (Atlanta’s highest barrier submarket with only 77 units delivering per year on average since 2005) and is the only new construction multifamily asset of scale (over 150 units) to come to market in over 25 years.

 

Also, the property is on the Alpha Loop, an 8-mile paved pathway connecting residents to lifestyle amenities like Downtown Alpharetta and Avalon’s 644K SF of retail.

 

Eden at Lakeview had an impressive 9 month lease up, averaging 27 leases a month (the fastest lease up in 3 years in Atlanta), while growing rents at 10%.

 

When are you available to discuss and/or tour?',TRUE,TRUE,''),
('The Edison Daytona','6 - Passed','DaytonaBeach, FL',262,2022,NULL,NULL,'2025-07-16','2025-06-25','2025-07-16','All Docs Saved - Need pricing',TRUE,TRUE,''),
('Elan Research Park','6 - Passed','Charlotte-Gastonia-Rock Hill, NC-SC',348,2023,252873,88000000,'2025-07-08','2025-06-03','2025-07-15','All Docs Saved - 
We’re guiding $255-260k/unit. That is a 5.15% cap rate holding 4% concessions which is leverage neutral assuming 5-year agency debt with a buy down. Moves to a ~5.5% cap when burning off concessions. 

CFO is Tuesday, July 8th. 

Elan Research Park offers a value proposition with $250 of rental headroom to top-of-market peers and strong in-place performance (2% renewal increases and 60% retention with no concessions). The affluent tenants (avg. $105K HHI, 19% rent-to-income), differentiated amenity set, declining submarket supply, and proximity to major employment (380K jobs within 20 minutes) further support long-term rent growth. 

We’ve provided some additional details below, but let us know if you would like to schedule a call or tour. 

•	 $1,711 Avg In-Place Rent / 943 Avg SF / $1.81 PSF
o	~$250 ($0.41 PSF) rental headroom to NOVEL University Place
•	Property has averaged 2% renewal rent increases while achieving a 60% retention ratio since August 2024 and the lowest concessions in the submarket
•	Highly curated rent roll with exceptional onsite demographics ($105k Avg HHI) with 19% average rent-to-income ratio
•	Differentiated amenity set both in-unit and across common areas:
o	Units – 10 Townhomes with private fenced-in yards, fenced yards on additional 28 ground-floor units, private dens in 40% of units serving as unique flex space for WFH renter
o	Common Areas – Resort style pool with separate lap lanes (only pool in submarket with lap lanes), pickleball court (only deal in submarket), 2 dog parks
•	University supply story quickly changing with a 90% decline in supply by 2026 
•	Within a 10-minute drive of the entire University Submarket (80K Jobs), Charlotte’s 2nd largest employment node
o	380K Jobs located within a 20-minute drive of the asset
•	Located 5-minutes from University Research Park (2,200 acre / 25k+ employee research park) and Vanguard’s new 2,400 employee campus  opened in May 2025
•	Highly amenitized location with 2M+ SF of retail within 1.5 miles – 5-minute drive from Target, IKEA, Harris Teeter, Starbucks, Chipotle, Chick-Fil-A, and TopGolf',TRUE,TRUE,''),
('Westlake Apartment Homes','6 - Passed','Orlando, FL',379,2000,216358,82000000,'2025-07-14','2025-06-05','2025-07-15','All Docs Saved - Westlake is a great property. 9’ and 10’ ceilings, great floor plans & unit mix, garages, two pools.  Excellent proximity to 70,000+ white-collar jobs in Lake Mary/Heathrow/Sanford office park. Most units available for renovations so strong value add upside here.  Blackstone is the seller.  Guidance of $82M.',TRUE,TRUE,''),
('Red Knot at Edinburgh','6 - Passed','Norfolk-Virginia Beach-Newport News, VA-NC',336,2015,284226,95500000,'2025-07-17','2025-06-17','2025-07-10','All Docs Saved - Hi Ethan, 

Please see below…happy to jump on a call and discuss in more detail. This is a phenomenal opportunity… Original developer, self-managed, no supply risk. 

RED KNOT AT EDINBURGH: Guidance is $95.5M+ equating to an attractive 5.6% adjusted in-place cap rate (T3 Rev/Pro Forma Expenses).  Red Knot stands out due to its superior construction, thoughtfully designed unit layouts, and exceptional amenities. It has consistently delivered strong operational performance, maintaining an average vacancy of just 1.94% while achieving an impressive 5.11% average annual rent growth since 2021.
 
A few additional deal highlights are below:
 
•	Core Stability with Value-Add Upside: New ownership can capitalize on a light value-add program (appliances/flooring) to bridge the $311/unit delta to top-of-market comparables. The submarket is projected to maintain an average rent growth of 3.34% and occupancy of 96.22% over the next 5 years. 
•	Affluent Renter Base: Within a one-mile radius, the average household income is nearly $180,000 and is projected to grow to over $200,000 by 2029. Zoned to three “A“ rated schools, this property is located in one of the best school districts in Virginia (#13 of 130). 
•	Near Zero Supply Pipeline: With zero units under construction and just one property in lease-up, Red Knot enjoys a uniquely protected position in a highly desirable submarket. 
•	Prime Location: Immediate access to major big box retailers (Target, Home Depot, Wal-Mart), popular dining (Chick-fil-A, Starbucks, Zaxby’s), and immediate connectivity via Virginia State Route 168, allowing for 10-18 minute commutes to Greenbriar Chesapeake and downtown Norfolk.',TRUE,TRUE,''),
('Hawthorne at Mirror Lake','6 - Passed','Atlanta, GA',250,2003,196000,49000000,NULL,'2025-02-17','2025-07-10','All Docs Saved - Ethan,

If you are looking for a property in an area with good growth surrounded by high end homes and 36 hole golf course, then this is one to focus on. 

HML includes a proven Value-Add Strategy with 39 renovated units achieving $150 premium with 115 classic units remaining in Phase 1 --- both phases offer nine foot ceilings and full array of amenities. 

January T12 for Hawthorne at Mirror Lake is posted and here are a few highlights:

-	2% vacancy loss. That makes 9 consecutive months with vacancy less than 5% on the T12
-	0.4% bad debt
-	0.5% concessions (down from 2% in December) as they continue to burnoff. No concessions currently being offered so this should be the case going forward.
-	Net Rental Income ($376K) is up 2.5% MoM
-	Total Income ($433K) is up 4% MoM

We are guiding to $49,000,000 all cash ($196K per unit) at a high 5 cap rate in place. CFO likely 2nd or 3rd week of March. Perfect deal size, it will underwrite well and our debt team will have financing options for you to consider. 

Tours are being scheduled now. Would you like to put something on the calendar?',TRUE,TRUE,''),
('Montrose Berkeley Lake','6 - Passed','Atlanta, GA',492,1988,180894,89000000,NULL,'2025-06-11','2025-07-09','Tracking PP - All Docs Saved - Thank you for reaching out on this.  The numbers for Montrose Berkeley Lake are outstanding:
 
•	Net Rental Income up 10% since 2022 (avg. 3% annually), Total Income up 9% (avg. 3+% annually)
•	Property averaging extremely low economic vacancy of 8% for three years
•	Bad debt loss less than 1% 
•	Zoned for A-rated Schools
•	Average HHI at the property is $80k
 
We expect to trade around $89 to $90 mm ($180k per unit) which is about a 5.8% cap (trending upwards) on T3/T12 tax adjusted numbers. CFO in mid July and you will get a reminder later. Titan manages the property for Investcorp.
 
When can you tour?',TRUE,TRUE,''),
('55 Resort Scottsdale Apartments','6 - Passed','Phoenix-Mesa, AZ',102,2025,350000,35700000,NULL,'2025-06-25','2025-07-09','All Docs Saved - Hi Jay, we plan to formally launch this offering next week and will likely be having a CFO either 7/24 or 7/31 – ownership is having a partnership dispute, is self managing, and has made the collective decision to sell this property at a noticeable loss. We anticipate pricing to be approximately $350,000 per unit and 20% below their cost basis – this reflects a 6.6% Proforma cap rate (attached). Below are additional details about the offering:

•	Property is currently 8% occupied and guidance pricing reflects a non-stabilized transaction with buyer completing lease up
•	2025 Construction with Final Certificate of Occupancy obtained in late-March, 2025
•	Three story, wrap construction with interior corridors, dual elevators (1 Resident/1 Freight), and over 20,000 SF of amenity space
•	Contemporary, high-end interior finishes with hard surface countertops, modern cabinetry, undercabinet lighting, tiled showers, and modern fixtures and hardware
•	One of only five apartments within McCormick Ranch and last build in over 30 years
•	1 & 3 Mile Demographics
o	Average Household Income: $169,229 / $171,692
o	Average Home Value: $1,500,000 / $1,700,000
o	Median Age: 54.0 / 52.1
•	Located along the 11-mile Scottsdale Green Belt with direct property access to trail system
•	Current market rents are $3,934 per unit that are all-inclusive (all utilities, internet/cable, valet trash, etc.); Colliers recommends lowering market rents to $2,500 per unit with individual charges for items 
•	Property is currently operating as Active Adult Plus (not licensed, no care, no shuttles, but has F&B) – property has a bar with Series 12 Liquor License that is non-transferable and requires 40% of sales be from food. Colliers recommends obtaining traditional Series 6 liquor license that does not require food sales and discontinuing this. 
•	W.E. O’Neil was General Contractor and warrantied through October 2026 with individual warranties that may extend longer',TRUE,TRUE,''),
('Avilla Broadway','6 - Passed','Phoenix-Mesa, AZ',117,2024,286324,33500000,'2025-07-16','2025-05-14','2025-07-09','All Docs Saved - -	Whisper Pricing Guidance: 

o	$33,500,000 ($286,325/unit) - $34,500,000 ($294,872/unit) which equates to a going-in cap rate of +/- 5.0%, with Year 1 cap project mid-5%’s.    Property will trade well below replacement costs
-	Other Information: 
o	Built 2024, Avg SF – 975, Avg. Rent $2,041 ($2.09/sqft)
?	1x 1 (690 SF) - $1,657 (38 Total Units) 
?	2 x 2 (984 SF) - $2,056 (43 Total Units) 
?	3 x 2 (1,265 SF) - $2,428 (36 Total Units 
-	Offering Link / Document Center:  
o	Link: Avilla Broadway Offering
-	Deal Notes: 
o	EPA Indoor AirPLUS Certified
o	97% Leased & 95% Occupied 
o	Stabilized in less than a year, Avg Monthly Absorption (16 Units/month)
o	51% of the leases executed at 15 months or longer. 

Attached is our offering memorandum and we are actively touring this opportunity now so call please at 602.526.4800 should you have additional questions.',TRUE,TRUE,'')
ON CONFLICT (name) DO NOTHING;

INSERT INTO deals (name,status,market,units,year_built,price_per_unit,purchase_price,bid_due_date,added,modified,comments,flagged,hot,broker) VALUES
('Yardly Paradisi','6 - Passed','Phoenix-Mesa, AZ',193,2023,NULL,NULL,NULL,'2025-07-08','2025-07-09','All Docs Saved',FALSE,TRUE,''),
('The Tyler','6 - Passed','Phoenix-Mesa, AZ',320,2023,400000,128000000,'2025-07-17','2025-06-11','2025-07-09','For Tracking PP - All Docs Saved - $128M - $130M',TRUE,TRUE,''),
('Residences Kierland','6 - Passed','Phoenix-Mesa, AZ',290,2022,517241,150000000,'2025-07-29','2025-06-12','2025-07-09','All Docs Saved - $150MM',TRUE,TRUE,''),
('Cyrene at Skyline','6 - Passed','Phoenix-Mesa, AZ',102,2025,431372,44000000,'2025-07-24','2025-05-29','2025-07-09','All Docs Saved - Hi Ethan,
Guidance is low 5s in-place cap for both, marking-to-market around a mid-5. Equates to low $400s/door for Painted Tree (Dallas), ~$430k/door for Skyline (Phoenix).',TRUE,TRUE,''),
('Arbor Ridge Apartments','6 - Passed','Baltimore, MD',348,1999,232758,81000000,'2025-07-29','2025-01-22','2025-07-09','All Docs Saved - 
Seller will sell for 81MM now
$85m --- Mid 5% Cap.',TRUE,TRUE,''),
('Hayloft Suwanee','6 - Passed','Atlanta, GA',98,2023,438775,43000000,'2025-07-22','2025-06-16','2025-07-09','All Docs Saved - Ethan,

Guidance here is $43-44M, which gets you to a 5.3%-5.4% Y1 stabilized yield.

Really unique product combination of age restricted and large floorplan BFR in a high-quality suburban Atlanta location.  No pipeline of comparable product in submarket and strong retention and trade outs that give support for continuation of growth trend.

Let us know a good time to connect and tell you more about the opportunity and also happy to schedule a tour.

Best,',TRUE,TRUE,''),
('L''Attitude 27 Riverview','6 - Passed','Tampa-St. Petersburg-Clearwater, FL',92,2024,326086,30000000,NULL,'2025-06-24','2025-07-09','All Docs Saved - Ethan – Hope you’re doing well, appreciate you reaching out.  

We’re targeting ± $30 million or $325,000 per unit range on pricing, which is about a 5% cap rate on the in-place rent roll (inclusive of current concessions), ramping to ± 5.4% territory in FY1 with moderate growth assumptions, and 6.0% upon concessions burning off. 

•	Brand-new, townhome build-to-rent community completed in August 2024 (built by Meritage Homes), now approaching initial stabilization.  
o	All two-story, 3BR x 2.5BA floor plans averaging 1,506 SF. 
o	26% of units feature desirable two-car garages (only community offering two-car garage TH product across the competitive set)
o	Thoughtful site plan layout with 33% of units featuring picturesque water feature views
•	Proven rent growth thru lease-up: 6%+ rent growth when comparing the last 2 leases signed by floorplan ($2,606) over opening rates ($2,457), while also leaving significant runway for growth on next-gen leases.   Lease trade-outs over the previous 90 days are averaging 8% growth, and no concessions are being offered on renewals. 
•	Several opportunities exist for light unit interior enhancements, such as fencing additional backyards (only 21 of 92 units feature fenced backyards, achieving $100/mo. premiums), replacing carpet with LPV on second floor, installing ceiling fans in bedrooms, adding kitchen backsplash, etc.  Additionally, an opportunity exists to add a small pool / amenity to vacant common area space (± 0.3 acres) at the Property’s entrance. 

No CFO date has been circled as of yet, but we’d anticipate offers being due around late July timeframe. 

We’re happy to hop on a phone call to share more of the backstory here.  Keep us posted with any questions in the interim, or if you’d like to schedule a tour of the community.  

Cheers,',TRUE,TRUE,''),
('Sentosa Riverview','6 - Passed','Tampa-St. Petersburg-Clearwater, FL',368,2022,260869,96000000,'2025-07-24','2025-06-16','2025-07-09','All Docs Saved - Hey Ethan, 

Initial pricing guidance is $96M, $261K/unit, a low/mid 5% year-one cap rate.

Sentosa Riverview is currently operating at sub 4% T3 vacancy, though has offered concessions due to ongoing roadwork directly in front of the property temporarily blocking it''s main entrance.  The roadwork should be completed in the coming weeks and given the absence of new supply within several miles, we expect concessions to burn off.

The continued improvements along US 301 will add a dedicated turn lane into the property and to the Black Rifle Coffee Shop, Chick-fil-A, and Chase Bank, all set to open directly in front of Sentosa.

Let us know if you have any questions.',TRUE,TRUE,''),
('Cottages at The Realm','6 - Passed','Dallas-Fort Worth, TX',72,2019,472222,34000000,NULL,'2025-07-07','2025-07-09','All Docs Saved - Hey Ethan,

Pricing guidance is $34mm, which is a low 5% in-place yield and low $200 PSF. 

Let me know if you have any additional questions.',FALSE,TRUE,''),
('Cyrene at Painted Tree','6 - Passed','Dallas-Fort Worth, TX',95,2025,410526,39000000,'2025-07-24','2025-05-29','2025-07-09','All Docs Saved - Hi Ethan,
Guidance is low 5s in-place cap for both, marking-to-market around a mid-5. Equates to low $400s/door for Painted Tree (Dallas), ~$430k/door for Skyline (Phoenix).',TRUE,TRUE,''),
('Haven at Birkdale Village','6 - Passed','Charlotte-Gastonia-Rock Hill, NC-SC',320,2001,312500,100000000,'2025-07-15','2025-05-28','2025-07-09','All Docs Saved - Mixed Use Sale Guidance is $315k/door for the multi alone.',TRUE,TRUE,''),
('Solaya','6 - Passed','Orlando, FL',322,2018,291925,94000000,'2025-07-16','2025-06-05','2025-07-09','All Docs Saved - South Orlando, near Sea World - probably not for us 
Pricing guidance is $94MM',TRUE,TRUE,''),
('Mason Stuart','6 - Passed','Fort Pierce-Port St. Lucie, FL',270,2024,280000,75600000,'2025-07-10','2024-12-11','2025-07-09','All Docs Saved - Target pricing is $280,000 per unit, 5.25 cap.  Brand new construction, just stabilizing.  Very close to downtown Stuart and the new Brightline Station. An excellent growth market.',TRUE,TRUE,''),
('Amelia at Farmers Market','6 - Passed','Dallas-Fort Worth, TX',297,2019,202020,60000000,'2025-07-09','2025-06-12','2025-07-09','Nice deal size and basis but I know we are out on Dallas for now. EJ  All Docs Saved - Low $60mm range',TRUE,TRUE,''),
('Marshall Springs at Gayton West','6 - Passed','Richmond-Petersburg, VA',420,2014,278571,117000000,'2025-07-15','2025-06-09','2025-07-09','For Tracking PP - All Docs Saved - Marshall Springs at Gayton West is a 420-unit Core Plus asset located in Short Pump, within the premier Western Henrico submarket. Owned and managed by the original developer, this asset offers investors the rare opportunity to implement low execution-risk value creation strategies to generate yield. Marshall Springs at Gayton West boasts exceptional historical performance with clear, actionable rental upside in Richmond’s most desirable submarket.

Guidance is mid-280k per unit equating to north of a 5.00% in-place adjusted cap rate.  A few additional deal highlights are below:
 
•	Significant Delta to Comparable Set: Average leased rents at Marshall Springs are $858 below top-of-market comparables and $390 below the average of the comparable set, representing a clear path to value for new ownership. Through implementation of a light value-add program, new ownership will be able to bridge the gap to direct comparables and unlock substantial value. (Example: Ownership is currently generating $200 rental rate premiums through installation of Stainless Steel appliances, nearly 100% ROI...) 

•	Dependable Performer: Averaging an astounding 5.43% average annual rent growth with an average vacancy of just 3.05% since 2021, this asset has demonstrated its ability to consistently perform through macroeconomic cycles. (Axiometrics projects over 4.00% average rent growth for this submarket over the next 5 years)

•	Prime Location: Located just minutes from the area’s top commercial and lifestyle locations - including Innsbrook Office Park (22,000 employees), West Creek Office Park (12,000 employees), Short Pump Town Center (1.5MSF of retail), and West Broad Marketplace (386KSF), Marshall Springs offers residents unmatched access to jobs, retail, and entertainment.

•	Highly Amenitized: With a splash area, outdoor cabanas with fireplaces, a standalone 24 /7 fitness building, billiards room, bocce court, and amphitheater, Marshall Springs provides residents with an unparalleled resort-style living experience.',TRUE,TRUE,''),
('The Grand','6 - Passed','Washington, DC-MD-VA',548,2000,346715,190000000,NULL,'2025-06-25','2025-07-09','For Tracking PP All Docs Saved - $190M 5.6% Cap',TRUE,TRUE,''),
('Rowan','6 - Passed','Washington, DC-MD-VA',353,2021,297450,105000000,NULL,'2025-06-24','2025-07-09','For Tracking PP All Docs Saved - $105MM Low 5% in place',TRUE,TRUE,''),
('Aspire Apollo','6 - Passed','Washington, DC-MD-VA',417,2016,290167,121000000,NULL,'2025-06-13','2025-07-09','For Tracking PP All Docs Saved - Yes all the same seller – PNGS. Guidance is: 

Aspire - $121mm',TRUE,TRUE,''),
('Ascend Apollo','6 - Passed','Washington, DC-MD-VA',424,2017,252358,107000000,NULL,'2025-06-13','2025-07-09','For Tracking PP All Docs Saved - Yes all the same seller – PNGS. Guidance is: 
Ascend - $107mm',TRUE,TRUE,''),
('Turnbury at Palm Beach Gardens','6 - Passed','West Palm Beach-Boca Raton, FL',542,1974,269372,146000000,'2025-07-15','2025-06-09','2025-07-09','For Tracking PP - All Docs Saved - Will - wanted to make sure you guys saw this one. Main & main location in Palm Beach Gardens. All two-story product, concrete block construction. Lots of different strategies available including a limited rehab, deep scope rehab or long term re-development.

Target pricing is $270k per unit, 5.25 in place cap adjusted for taxes. Let us know if you’d like to set up a tour.',TRUE,TRUE,''),
('The Seabourn','6 - Passed','West Palm Beach-Boca Raton, FL',456,2012,399122,182000000,'2025-07-16','2025-06-10','2025-07-09','For Tracking PP - All Docs Saved - Hi Ethan,

Guidance on The Seabourn is around $400k per unit for the multi - which is a 4.8% cap in place with insurance at $1,500 per unit - plus an additional $3 - $4 million for the development piece, which is in the latter stages of site plan approval for an additional 149 units.

Very unique product with 2/3 townhome-style units with direct access garages and large apartments averaging 1,302 square feet.

It’s a great location on a 24-acre site in East Boynton Beach along Federal highway, ~five minutes north of Atlantic Avenue in Delray.

Ownership has invested $5+ million in the community over the past few years, including extensive upgrades and reprogramming of common areas and amenities, preventative maintenance and upgrading 22 unit interiors. The upgraded units get a ~$320 premium so there is plenty of upside remaining in updating the remaining units.

Worth noting that we included an insurance quote from Lockton in the deal room ranging from $1,217 - $1,602 per unit, depending on coverage requirements.

Let me know if you’d like to discuss further or arrange a tour.',TRUE,TRUE,''),
('Allure Apollo','6 - Passed','Washington, DC-MD-VA',384,2019,317708,122000000,NULL,'2025-06-13','2025-07-09','For Tracking PP All Docs Saved - Yes all the same seller – PNGS. Guidance is: 
Allure - $122mm',TRUE,TRUE,''),
('Big Sky Flats','6 - Passed','Washington, DC-MD-VA',108,2022,111111,12000000,NULL,'2025-06-25','2025-07-08','All Docs Saved - Midcity is seller (same as Wash Apts) 12-13M',TRUE,TRUE,''),
('Allure on Enterprise Apartment Homes - BTR','6 - Passed','DaytonaBeach, FL',130,2022,234615,30500000,NULL,'2025-01-27','2025-06-27','Coming Soon - Thank you for your interest in Allure on Enterprise, a 130-unit BTR community featuring 70 townhomes and 60 flats with 122 attached garages. The property sits on a low-density site with 9.5 acres per unit and is strategically located within a 30-minute commute to both Orlando and Daytona Beach.
 
Allure on Enterprise offers some of the most spacious floorplans in the submarket, averaging 1,293 RSF, constructed of concrete block on the first level. The property has demonstrated strong performance, maintaining an average occupancy rate of 95% over the past 12 months and achieving positive lease trade-outs for both renewals and new leases. Given the limited competition in the area and the strength of the competitive set, we identify an opportunity to increase market rents by an average of $192. Additional value-add opportunities, such as implementing private backyards or a tech package could further drive rent growth.
 
We anticipate the property to trade at ~ $30,500,000 ($234,615/unit) which equates to a tax and insurance adjusted 5.25% takeover CAP rate with the ability to achieve a 6% YR1 proforma cap rate.
 
If you would like to discuss the opportunity further or schedule a site tour, please contact the lead agents below.',TRUE,TRUE,''),
('Charter Oak Apartments','6 - Passed','Washington, DC-MD-VA',262,1970,263358,69000000,'2025-06-26','2025-05-29','2025-06-26','All Docs Saved -  We just released the OM and will be in the market for another four weeks or so.  We are guiding to $69 mm | $263K per unit | 5.2% T-90 Revenue T-12 Expenses Tax Adjusted Cap Rate | 6.5% Stable Cap Rate Post Value-Add.  
 
There’s a ton of upside: 
 
•	126 Classic Units - Achieve monthly premiums upwards of $250 per unit with interior improvements 
•	132 Previously Renovated (10 years - JBG Smith) - minor upgrades could generate $50-$100 per unit premium
•	Converting 2 BR | 1 BA units to 2 BR | 2 BA or 3 BR | 2 BA units (eight converted) - $400-$600 per unit premium
•	Increase Amenity Fee for Reston Association Fees – Competitive communities charge higher fees – $225k of additional Other Income
•	Increasing Utility and Trash reimbursements from ~70% to upwards of 90%+ - $150k of additional Other Income

Thanks and let me know if you all want a follow up call or to schedule a tour – Jonathan',TRUE,TRUE,''),
('Addison Square Apartments','6 - Passed','Melbourne-Titusville-Palm Bay, FL',270,2024,351851,95000000,'2025-06-26','2025-05-29','2025-06-26','All Docs Saved - Guidance is $355k per unit, which is a high 5’s on in-place rents if you burn the one-month concession. 

Key deal points below. We’ve included a lot on the lifestyle & economy on the Space Coast in the Executive Summary, but let us know if you’d like to do a screenshare and talk through the project & location further.

Property & UW Information – 
•	Best-in-market execution including custom-home interior unit finish levels & unmatched amenity offering
•	$2,410 in-place rents, with recent leases by floorplan at $2,475
•	Minimal concessions throughout lease-up, averaging just under one month free
•	Highly elevated Parking/Storage & Other Income items
•	Preferential tax treatment with Brevard County – 48-63% post-acquisition assessment over the last 3 years
o	Lowest millage rate we’ve seen on a property in Central Florida at just 11.96

Centrally located to the Space Coast’s premier lifestyle and employment corridors – 
•	Walking distance to the Health First Viera Hospital’s 50-Acre Health Campus & Publix
•	<5 Min to The Avenue Viera
o	Trader Joes and Topgolf recently announced their first Space Coast locations within The Avenue coming in late 2025.
o	2.1MSF of retail within a 2-mile radius including retailers such as Target, Publix, Lululemon, Nordstrom Rack, Starbucks, and Urban Prime.
•	<10 Min to Whole Foods first Space Coast location under construction coming early 2026.
•	<15 Min to the Beach
•	<20 Min to Melbourne Airport & Surrounding Employment Campuses (19K Tech and Space Industry Jobs)
•	<30 Min to the Kennedy Space Center (14K Tech and Space Industry Jobs)

Exceptional Demographics & Schools – 
•	On-Site Demographics
o	Avg / Median HHI: $176K / $135K
•	‘A’ Rated Schools
o	Quest Elementary School (Walkable to Addison): FDOE Rating ‘A’ / Great Schools 9/10
o	Viera Middle School: No ratings yet, first middle school to be built in Brevard Count in last 30 years
o	Viera High School: FDOE Rating ‘A’ / Great Schools 7/10
•	Strong demographics when compared to Orlando’s most prestigious neighborhoods',TRUE,TRUE,''),
('Anya','6 - Passed','West Palm Beach-Boca Raton, FL',223,2023,NULL,NULL,NULL,'2024-10-01','2025-06-25','',TRUE,TRUE,''),
('River North','6 - Passed','Fort Pierce-Port St. Lucie, FL',280,2023,300000,84000000,'2025-06-25','2025-05-19','2025-06-25','All Docs Saved - Hi Ethan,


It’s a nice new construction deal fully leased up. Stuart/PSL has zero new supply coming in and lots of people moving to the area. Guidance is $300K per door which is below replacement cost and a 5% cap in place. It hits a 6% cap after you burn off concessions. Want to set up a tour?',TRUE,TRUE,''),
('Avana City Park','6 - Passed','Tampa-St. Petersburg-Clearwater, FL',228,1990,247807,56500000,'2025-06-24','2025-05-21','2025-06-24','All Docs Saved - Greystar deal $56.5M, $247k per unit, 5.6% T3 tax adjusted cap rate, 6% year 1.  Phenomenal in place yield with upside!  The majority of the units, 119 out of 220, are available for upgrades with 64 classic units and 65 partially renovated.

Property performance is really strong with 97% occupancy and 5.7% lease trade outs.',TRUE,TRUE,''),
('Trace','6 - Passed','Atlanta, GA',290,2016,327586,95000000,'2025-06-24','2025-05-29','2025-06-24','All Docs Saved - Pricing is $95M ($328K/Unit), reflecting unabated cap rates of 5.13% Year 1 and 6.57% Year 3. 



This is 51% below replacement cost.



The offering also includes two retail spaces (~8.5K SF) and two years of remaining tax abatement.



5.13% Year 1 Cap Rate: Based on $2.70 PSF rents which includes renovations to 1/3 of units in year one. 



6.57% Year 3 Cap Rate: Based on $3.21 PSF rents following a fully completed renovation program.



Trace Midtown is well-constructed JLB product with 10+ foot ceilings and concrete construction. 



The Peachtree Street location offers walkability to Tech Square, 116K+ nearby jobs, and proximity to Atlanta’s top neighborhoods and developments.



The OM will be available next week.',TRUE,TRUE,''),
('Bella Grace','6 - Passed','Phoenix-Mesa, AZ',194,2017,340206,66000000,'2025-06-18','2025-05-12','2025-06-19','All Docs Saved - 
Attached and below is our  latest offering in The East Valley of Metro Phoenix that may be of interest - Bella Grace (194 Units) which has a value-add component in addition to generating new leases trade outs at 4% + YoY.   

Bella Grace is well positioned in the supply - constrained Chandler submarket. Given the high quality of asset and the fact that this community consistently operates full with no concessions,  we are whispering a range of $66,800,000 - $68,800,000.   This suggested pricing equates to a 5+/- CAP Day One and a 5.2 – 5.35-year 1 CAP assuming you do not renovate the asset. Our projected CAP bumps over 5.5 if partly renovated.

-	Website: https://properties.berkadia.com/bella-grace-472187

Please call as questions arise. And we are actively touring this opportunity.',TRUE,TRUE,''),
('The Shirley','6 - Passed','Baltimore, MD',270,2021,333333,90000000,'2025-06-17','2025-05-09','2025-06-18','All Docs Saved - Stockbridge bought for $78MM in 21

- Hey Ethan - guidance is $90MM+ (~$340K/Unit), low-5% cap rate with full taxes. Let us know if you want to set up a tour.',TRUE,TRUE,''),
('The Commodore','6 - Passed','Washington, DC-MD-VA',423,2023,531914,225000000,NULL,'2025-06-18','2025-06-18','Tracking PP - All Docs Saved, Greystar, ground lease
$225M – allocating ~$15 to the retail, which is a stabilized 7% cap on NNN income, and $210 to the resi, which is a normalized 5% cap rate. Let me know if you guys want to schedule a tour ahead of CFO. I imagine this one might be to big but let me know otherwise.',TRUE,TRUE,''),
('Riverchase Vista','6 - Passed','Savannah, GA',300,2024,246666,74000000,'2025-06-17','2025-05-29','2025-06-18','All Docs Saved - •	Pricing is $74M ($247k/unit), which is a 5.80% stabilized cap rate through increasing rents by less 3% from recent leases in Year 1.
•	Asset Highlights:  
o	Occupancy: 96%; Avg. Rent: $1,697; Avg. SF: 950 
o	Recent leases are currently achieving ~$1,800, which is $100 (6%+) higher than in-place rents.
o	New Lease trade outs are averaging 13% increases and renewals are 9.5% while maintaining a 70% retention rate.
o	Lease-up velocity was 20 move-ins per month
•	Submarket Highlights:
o	Top Demographics: Average HHI at the property is ~$108K+.
o	Great visibility and direct access to major employers and top retail corridors via I-16 
o	Generational growth with the 8K jobs from Hyundai EV Plant that will lead to total of 40K total new jobs in the metro (20% of current work force), with 18K already announced. 
o	Savannah MSA needs 41,000 new housing units by 2030
•	CFO: Tuesday, June 17th',TRUE,TRUE,''),
('Ascend Rippon','6 - Passed','Washington, DC-MD-VA',236,2024,353813,83500000,'2025-06-17','2025-05-16','2025-06-18','All Docs Saved - Hi Ethan – for pricing, we’re guiding to $83.5M ($354k/unit), which works out to a 5.65% Year 1 cap.',TRUE,TRUE,''),
('Montecito','6 - Passed','Houston, TX',299,1997,157190,47000000,'2025-06-17','2025-05-21','2025-06-18','All Docs Saved - Hi jay, 47mm guidance.  Seller expenses will need to be adjusted.  Happy to discuss as you dig in.  CFO is on Tuesday the 17th.',TRUE,TRUE,''),
('Legends at Laurel Canyon','6 - Passed','Atlanta, GA',266,2020,229323,61000000,'2025-06-17','2025-05-20','2025-06-18','All Docs Saved - Probably too far out, but nice Loan assumption 3.47% Fixed FTIO for 5 more yrs

Pricing should be +/- in the mid to upper $230k’s/unit range which translates to +/- 5.25% Y1 Cap.  This opportunity is offered as a Loan Assumption with very attractive in-place Fannie debt at a 3.47% rate, 1.5 years remaining of I/O, and a $40.53MM current balance.  With the accretive debt a new investor will achieve 7%+ cash-on-cash year one before any supplemental loan.

A few key points to consider:
•	2020 Vintage; Original Developer Owned
•	Significant Discount to Replacement Cost
•	Proximate to 800,000+ jobs
•	Explosive Growth Location with Superb Demographics 
•	Walkable to adjacent Publix anchored retail center 

Property Website:  Legends at Laurel Canyon 

We are currently scheduling tours, are you available to tour next week or the week after?  Just let us know what works for you and we will do our best to accommodate.  Call for Offers has not been set yet, but will be mid-June.',TRUE,TRUE,''),
('Aura 509','6 - Passed','Raleigh-Durham-Chapel Hill, NC',182,2023,285714,52000000,'2025-06-17','2025-05-07','2025-06-18','All Docs Saved - Ethan-  

Thank you for reaching out. We are guiding to $290k/unit (YR1 stabilized 5% cap), which represents a compelling 20% discount to replacement cost to podium construction.
 
Aura 509 boasts an unparalleled Downtown Durham location, offering:
 
•	Walkable access to diverse dining and entertainment options, including Durham Food Hall, The Durham Farmer’s Market, and Central Park
•	Minutes from Google’s Durham ID office and other major employers
•	10-minute drive to Duke University and Duke Health
•	A few-minutes from The Bullpen, Durham’s first social district
 
We would love to hop on a call and talk through the opportunity in more detail whenever you are available.',TRUE,TRUE,''),
('Hermitage Apartment Homes','6 - Passed','Tampa-St. Petersburg-Clearwater, FL',348,2017,448275,156000000,'2025-03-20','2025-02-20','2025-06-17','All Docs Saved - Mid $400s per unit',TRUE,TRUE,''),
('Raven South End','6 - Passed','Charlotte-Gastonia-Rock Hill, NC-SC',261,2023,337164,88000000,'2025-06-12','2025-05-09','2025-06-13','All Docs Saved - Hey guys, $340k per unit range. Yield is in the high 4.00s, and rents have a ton of runway. There is also a tax abatement pushing Y1 into the low 5.00s. Legit 30%+ discount to peak submarket midrise pricing, which is just down the street.
 
Quick Hits:
•	94% occupied
•	$108K avg HHI & 0% bad debt
•	Surrounding construction artificially suppressed rents during lease up - Everly across the street is $280 higher
•	6.9% trade-outs on new leases
•	Awesome amenities. Summit Coffee just opened on the ground floor, on site pocket park hosts food trucks, markets, etc.
•	4 years of brownfield abatement remaining',TRUE,TRUE,''),
('The Lindley at Grove 98 Apartments','6 - Passed','Raleigh-Durham-Chapel Hill, NC',232,2023,297413,69000000,NULL,'2025-04-16','2025-06-12','All Docs Saved - Hey Will (and Kees)!

acq meeting: if we could pay 270s maybe interesting 
 
By way of follow-up, we just went live with our off-market process for The Lindley at Grove 98 Apartments (initial offers due 4/29; 6/29/25 loan maturity).  
 
To help expedite Stonebridge’s initial screening, please see below, and attached, 
 
•	Confidentiality Agreement HERE: Lindley at Grove 98 CA (please click/sign to access our war room; OM to follow later this week)
 
•	The Lindley at Grove 98 Apartments | Highlights:
o	Collateral = 232, 3-story garden units; final building CO: Jan/2024: https://thelindleyatgrove98.com/
o	Anticipated summer stabilization = 73.4% occ, 80.8% leased
o	Avg effective rent (RR) = $1,795 | $1.65/sf
o	Avg effective rent (as if stabilized) = $1,860 | 1.71/sf
o	Robust onsite demo = avg HHI @ ~$107K (ability to support $2,943 at 33% rent-to-income) 
o	No supply = 0 conventional MF pipeline (5-mile radius, 1 proposed) after leasing up against ~2.1K units delivered since 1Q2023
o	Continued area transformation = 
?	2nd gen residents now have access to 80,000 SF of coveted retailers in backyard
?	Costco in 4Q24, announced its submittal of plans for a 5th RDU store behind Collateral (adjacent to Lowes Home Improvement)
o	Proof of concept = achieving a 64% retention on 29 renewals to date (12.5% of total units) achieving ~3% lease-over-lease increase
 
•	High Profile Project Team:
o	Developer (of 100% of the retail and MF components) = Stiles
?	https://www.stiles.com/
?	HQ’d in Ft Lauderdale, high profile MXU developer with +5-decade, prestigious history
o	MF property mgt = Greystar
o	Developer (of 394 for-sale townhomes east of Wegmans; under construction, completed delivery in 2025) = Stanley Martin
 
•	Basis / Initial Pricing Guidance:
o	All-in construction cost (including land) = ~$69MM (mid $290K/unit)
?	Per unit basis premium largely tied to delivery of one of RDU’s most stunning, irreplaceable clubhouses (8.5K sf), Class A+ interior, custom-built finishes, amenities (but spread across just 232 units)
o	Anticipated initial per unit pricing formation = Low $290K/unit
 
Our larger team is connecting tomorrow afternoon to review our BOV drafts for Columns (debt looking better and better) and Haven.  We will be in a position on Wednesday to preview and send. 
 
We complete finalist interviews tomorrow for Tribute, FYI. Interesting times.',TRUE,TRUE,''),
('Tamarak Apartments','6 - Passed','Phoenix-Mesa, AZ',56,1981,NULL,NULL,'2025-06-24','2025-05-22','2025-06-11','All Docs Saved - VA portfolio',TRUE,TRUE,''),
('Aventon Crown','6 - Passed','Washington, DC-MD-VA',386,2022,336787,130000000,NULL,'2023-11-06','2025-06-11','off mkt from Brenden
some additional performance context for your reference:
-	The property reached stabilized occupancy in October ’22; since stabilization (as illustrated within the other income analysis) the property has continued to increase rental rates for parking and storage as well as continued growth to ERI by 5.1%.

-	Aventon Crown averaged 30+ units per month during lease-up while increasing asking rents over from the original rents set in November 2021 and removing all concessions being offered (see chart below)

-	Continued rent growth is supported by the highly affluent demographic base at the property
o	Mean household income is $291k which is 10.1x times the average annual leased rent
o	Medium household income is $121k which is 4.2x times the average annual leased rent

-	The new Crown High School will be a 10 minute walk from the property with scheduled completion by 2026

-	Walking distance to Downtown Crown encompassing exceptional retail & entertainment options including Ted’s Bulletin, Ruth Chris Steak House, LA Fitness, and more.',TRUE,TRUE,''),
('Cimarron Apartments','6 - Passed','Phoenix-Mesa, AZ',210,1985,NULL,NULL,'2025-06-24','2025-05-22','2025-06-11','All Docs Saved - VA portfolio',TRUE,TRUE,''),
('North Country Club Apartments','6 - Passed','Phoenix-Mesa, AZ',92,1979,NULL,NULL,'2025-06-24','2025-05-22','2025-06-11','All Docs Saved - VA portfolio',TRUE,TRUE,''),
('Emparrado Apartments','6 - Passed','Phoenix-Mesa, AZ',154,1987,NULL,NULL,'2025-06-24','2025-05-22','2025-06-11','All Docs Saved - VA portfolio',TRUE,TRUE,''),
('Sedona|Slate','6 - Passed','Washington, DC-MD-VA',474,2013,485232,230000000,NULL,'2025-05-29','2025-06-10','All Docs Saved - High $230M''s',TRUE,TRUE,''),
('Novel Independence Park','6 - Passed','Tampa-St. Petersburg-Clearwater, FL',277,2024,357400,99000000,'2025-06-25','2025-05-14','2025-06-10','All Docs Saved - Guidance is $99M, $355-360k per unit. They are 83% net leased, finishing the initial lease-up. They have trended rents throughout the lease-up and haven’t given more than a month free on new leases, none on the limited renewals. Few other key deal points below – 

•	Differentiated, 5-story, conditioned-corridor, surface-parked Crescent execution
•	First surface-parked deal to be built w/i 3.5 miles in 15 years
•	New, unique living option in Westshore, which is predominantly 6-15 year old wood frame wrap deals
•	Versatile location surrounded by Rocky Point Golf Course, high-end single family homes, substantial office space & the Tampa International Airport
•	Westshore is the largest office submarket in FL (18.5 MSF) and leads the other MSA office submarkets in every statistical category 
•	Sweet spot resident profile – 37 years old, $200k+ avg HHI, nearly $150k median',TRUE,TRUE,''),
('The Clarendon Apartments','6 - Passed','Washington, DC-MD-VA',292,2005,513698,150000000,NULL,'2025-05-22','2025-06-06','For Tracking PP - EQR Deal $150M 5% Cap',TRUE,TRUE,''),
('The Vivian Apartments','6 - Passed','Atlanta, GA',325,2023,261538,85000000,'2025-06-04','2025-05-23','2025-06-06','For Tracking PP, Tax Abatement Deal. All Docs Saved - Ethan - Pricing is $85M ($262K/Unit), or $248K/Unit for multifamily only, which reflects the 6.16% Y1 cap rate.',TRUE,TRUE,''),
('SeaLofts at Boynton Village','6 - Passed','West Palm Beach-Boca Raton, FL',433,2021,207852,90000000,NULL,'2025-05-20','2025-06-05','All Docs Saved  - $90MM - Ground Lease',TRUE,TRUE,''),
('Ventura Pointe','6 - Passed','Fort Lauderdale-Hollywood, FL',206,2018,339805,70000000,'2025-06-04','2024-07-09','2025-06-05','All docs saved -
Now with Newmark - Still $70MM
CBRE - We appreciate you reaching out. We feel this one should land in the $340k per unit range which is right at replacement cost. Cap rate here will be just under a 5%.',TRUE,TRUE,''),
('Chase Heritage','6 - Passed','Washington, DC-MD-VA',236,1986,305084,72000000,NULL,'2025-01-27','2025-06-03','All Docs Saved - Thanks for reaching out.  A few points on the deal follow:

236-unit, value-add garden property in Loudoun County, VA. 
We are guiding toward $72mm | $305k per unit
Equates to a 5.50% T-90, tax-adjusted in-place cap rate
Post renovation pro forma cap rate is 6.25% | 75 bps above in-place
Monthly rent averages $2,131 per unit | $2.17 PSF | no concessions and minimal Bad Debt
Based on the competitive set, we are projecting a ~$200 per unit value-add premium

Let us know if you would like to set-up a tour after NMHC.',TRUE,TRUE,''),
('The Place at Arroyo Verde','6 - Passed','Tucson, AZ',156,2024,250000,39000000,NULL,'2025-02-12','2025-05-30','All Docs Saved - 250k per unit',TRUE,TRUE,''),
('Berkshires at Town Center Apartments','6 - Passed','Baltimore, MD',211,1964,218009,46000000,NULL,'2025-02-04','2025-05-30','All Docs Saved - Around $46M',TRUE,TRUE,''),
('Six Hundred West Main','6 - Passed','Charlottesville, VA',55,2020,400000,22000000,NULL,'2025-05-29','2025-05-29','All Docs Saved - $22MM',TRUE,TRUE,''),
('Pavilions On Central Apartments','6 - Passed','Phoenix-Mesa, AZ',254,2000,338582,86000000,'2025-06-04','2025-04-30','2025-05-29','All Docs Saved - Jay, guidance is $86,000,000.  It is a very nice asset.  More like infill build-to-rent because of the large units and the 85% direct-access garages.  The cap rate is 5.35% on trailing and 5.75% on FY 1.',TRUE,TRUE,''),
('Jamison Park','6 - Passed','Charleston-North Charleston, SC',216,2001,171296,37000000,'2025-06-11','2025-05-15','2025-05-29','All Docs Saved - Ethan – Hope all is well. Pricing guidance is $175k - $180k/unit, which is a tax and insurance adjusted low to mid 5% cap at 95% occupancy on T3 numbers (96% today). Following the completion of the renovations in year 3, this pushes the yield on cost near 7%. Jamison Park presents an outstanding opportunity to acquire a clean, institutionally maintained asset held by the same owner for the last 10+ years, well below replacement cost in a high barrier to entry growing Charleston submarket. Current ownership has spent almost $2M on the interiors/exteriors of the property, allowing new ownership to focus efforts on a Class-A renovation scope to match market comparables and push rents up to $300. 

Call for Offers is set for June 11th. Let us know if you have any questions or want to set up a tour.',TRUE,TRUE,''),
('Link Apartments Mixson','6 - Passed','Charleston-North Charleston, SC',358,2014,215083,77000000,'2025-06-11','2025-04-30','2025-05-29','All Docs Saved - Ethan - Thanks for reaching out. We are guiding to $77mm ($215k/unit) which is a stabilized 6% cap after finishing the value-add program (~$220 premiums on a $9500 reno). 

This pocket has fantastic supply/demand fundamentals- no assets under construction within 3.5-miles of the property and only ~350 units left to lease from recently delivered product.

Recent leasing has reflected positive growth on both renewals and new leases, and there is significant room for rents to run further given the supply dynamics and the ~$250+ average delta to competitive properties. 

If this one is a good fit for you guys, let us know when you’re available to catch up and discuss.',TRUE,TRUE,''),
('Solaire at Coconut Creek Apartments','6 - Passed','Fort Lauderdale-Hollywood, FL',270,2014,370370,100000000,'2025-06-18','2025-05-21','2025-05-29','All Docs Saved - Ethan…Target is $370’s per unit. Thanks.',TRUE,TRUE,''),
('Arts District Apartments','6 - Passed','Phoenix-Mesa, AZ',280,2017,285714,80000000,NULL,'2025-01-23','2025-05-29','All Docs Saved - $80MM, lender controlled sale 

Arts District Apartments:
-	280 units built 2017 by Alliance 
-	$80M or ~286k/door
o	Seems like a great basis compared to high 300s to build new (thinking of Mezzo)
o	5.3 cap per broker
-	Sold for $127MM (453k/unit) in 2022 with an 80% bridge loan (lender is involved in sale)
-	Strategy – can do light value-add (2-3k/unit) or do nothing as it was built to high standards
-	Location – downtown Phoenix in the Arts District. Sounds like a good location but need to do more research.',TRUE,TRUE,''),
('Intersect at O','6 - Passed','Washington, DC-MD-VA',74,2023,459459,34000000,NULL,'2025-05-09','2025-05-29','All Docs Saved -Ethan,
 
Great to hear from you.  We’re targeting $34m for the deal which is a 5.85% cap rate on proforma.  This will largely be a proforma exercise because the property, which is currently owned by Roadside Development & Grosvenor, is currently being operated out of City Market at O adjacent to the property.  The current operations reflect shared expenses and access to the amenities at City Market which will not continue going forward.  You will need to take a look at the deal on a standalone basis without access to City Market at O’s parking or amenities going forward. 
 
I would be happy to jump on a call to discuss in greater detail at your convenience.  We should probably setup a call to discuss what you guys are looking at currently and where we should be focusing our efforts.  Let me know a few times that work best for you.
Best,',TRUE,TRUE,''),
('Alta 801','6 - Passed','Washington, DC-MD-VA',327,2023,336391,110000000,NULL,'2025-05-22','2025-05-29','All Docs Saved - ~$110MM ($336K/Unit), mid-5% stabilized cap rate.',TRUE,TRUE,''),
('The Spoke Savannah','6 - Passed','Savannah, GA',106,2023,132075,14000000,NULL,'2025-05-23','2025-05-29','All Docs Saved - Ethan, Thanks for your interest in the Spoke opportunity! This is a fantastic node of close-in Savannah; a block from the Fresh Market-anchored center on Abercorn, and a short distance from both major regional hospitals.  
 
The property has been undergoing construction of a new clubhouse/amenity facility which has been a bit disruptive, but that work is slated for completion this summer.  The new clubhouse,  combined with the high-barrier/low-supply nature of the neighborhood, is creating clear pent-up rent growth at Spoke Savannah that can be unlocked near-term.
 
We anticipate pricing in the mid-teens ($14M-$15M range), or $135K-$140Ks per unit.
 
Please let us know of any questions or would like to set up a site visit,',TRUE,TRUE,''),
('Preserve at Mill Creek','6 - Passed','Atlanta, GA',400,2001,220000,88000000,'2025-05-28','2025-04-21','2025-05-29','All Docs Saved  - Good afternoon, Ethan, and Jay.  

The pricing on Preserve is mid $220’s/unit to low $230’s/unit. Here are a few highlights: 

•	Property is in great condition with limited exterior physical needs
•	Significant Value Add Opportunity exists:   
o	232 Classic units 
o	168 renovated units with upside remaining through faux wood flooring, bathroom renovations etc. 
o	163 units without washers and dryers in the units
o	No valet trash 
o	Garage income increased another $50 to $200/month, currently fully occupied
•	Right side of supply with no projected starts in 2025 and beyond
•	Projected rent growth 3%+/year

I hope this helps. Let us know if you want to schedule a property tour and/or discuss further. 

Sincerely, 

Derrick',TRUE,TRUE,''),
('Jefferson Place','6 - Passed','Washington, DC-MD-VA',228,2017,307017,70000000,NULL,'2025-04-10','2025-05-29','All Docs Saved  - $70MM

acq meeting: not worth touring unless could pay closer to 65M',TRUE,TRUE,''),
('Enclave at Rivergate','6 - Passed','Charlotte-Gastonia-Rock Hill, NC-SC',216,2009,250000,54000000,'2024-06-13','2024-06-03','2025-05-28','all docs saved

$250k per unit / $210 per sq. ft. (1,200 sf units, largest in the submarket and heavy 2BR weighting). That represents just north of a 5.5% cap on in-place T3/T12 with the new tax value and updated insurance expense.  One of the best performing deals we have reviewed in 12 months.',TRUE,TRUE,''),
('Ravinia - St. Lucie Rental Homes','6 - Passed','Fort Pierce-Port St. Lucie, FL',148,2023,358108,53000000,NULL,'2025-05-20','2025-05-27','For Tracking PP - All Docs Saved - Ethan – good afternoon.

We are guiding $360K per unit which is a low 5s in-place. Please see key deal points below – 

•	Fully Stabilized: 95% Occupied / 98% Leased
•	67% Four-Bedroom Homes / 33% Three-Bedroom Homes
•	Opportunity to implement fenced-in yards, Smart Home features and insourcing current landscaping contract (Approx. $60K annual savings)
•	One of only two managed detached single-family home communities within a 40-mile radius
•	Highly Accessible to Treasure Coast Lifestyle
o	<5 Min to ‘A’ Rated Elementary
o	<10 Min to Historic Downtown Fort Pierce
o	<15 Min to the Beaches
o	<35 Min to Palm Beach County

Let us know if you have any questions.

Thanks,',TRUE,TRUE,''),
('Del Oro Apartment Homes','6 - Passed','Fort Lauderdale-Hollywood, FL',345,1973,220289,76000000,NULL,'2025-05-14','2025-05-21','For Tracking PP - All Docs Saved - Guidance is $76M / $220k/unit, in-place 5.5 cap with adjusted taxes. Great value add opportunity with renovated units achieving $375 premium. 

Would you like to schedule a tour?',TRUE,TRUE,''),
('Cortland Hollywood','6 - Passed','Fort Lauderdale-Hollywood, FL',336,2016,360119,121000000,NULL,'2025-05-13','2025-05-21','All Docs Saved - Ethan…they can be split up. Target on Hollywood is $121mn and $85mn on Orange. Thanks.',TRUE,TRUE,''),
('Grove Landing BTR','6 - Passed','Macon, GA',139,2025,251798,35000000,NULL,'2025-05-08','2025-05-20','All Docs Saved - No OM yet - Thanks for reaching out. Pricing guidance is upper $34Ms or $250K/unit – well below replacement cost and a very-high 5% FY1 cap rate. A few additional notes on the opportunity:
•	139 high-quality single-family detached BTR product offering “for sale” quality finishes, including granite countertops throughout, premium stainless-steel appliances, vinyl-plank flooring, and W/D sets in all units
•	Curated unit mix offers 84% 3 & 4BR units averaging spacious 1,259 SF per home
•	Multifamily-style amenity set includes resort style-pool and pavilion, dedicated leasing space, outdoor playground, outdoor fitness center, and plentiful green space
•	Stellar lease-up performance averaging 8 move-ins per month and pushing 3 and 4-BR rents 4.2% and 7.1%, respectively
•	80%+ retention on initial expirations and pushing renewals +5.3% on average with no concessions
•	Lack of supply supports strong rent growth projections in Warner Robins: no BTR or MF projects under construction in the MSA (which has seen 2,600 MF & BTR units delivered over past cycle) and strong forward 3-yr avg. rent growth CAGR of 3.1% (axiometrics)
•	In the past two years Warner Robins has attracted 4,400+ jobs and $2.5 billion in investments in economic investment. The State of Georgia has unveiled a new 1,470+ acre Megasite less than 15-minutes from the property.
•	Excellent proximity (<10 min. drive) to highly regarded elementary and middle schools as well as daily conveniences such as Publix, Kroger, Walmart Supercenter, the Home Depot, and Starbucks

We will have the OM available within the week. Would you like to set up a time to go over this virtually or on-site in the coming weeks?',TRUE,TRUE,''),
('Cortland at Raven','6 - Passed','Phoenix-Mesa, AZ',192,2001,325520,62500000,'2024-09-19','2024-09-04','2025-05-16','All Docs Saved - Guidance is $61-64M which is an in-place 5% - 5.25% cap rate on PF expenses.',TRUE,TRUE,''),
('Casa Brera at Toscana Isles','6 - Passed','West Palm Beach-Boca Raton, FL',206,2014,315533,65000000,'2025-05-15','2025-04-21','2025-05-16','All Docs Saved - Target pricing is $315,000 per unit.  Great suburban location serving the Boynton Beach submarket.  Homes in the adjacent housing development sell for >$1MM.  Good opportunity to upgrade the amenities and do enhancements in the units.  The property does have workforce housing units… only one unit is within $180 of the rent limits, most well north of $250. Let me know if you would like to arrange a call or tour of the property. Including Danny Matz for debt quotes.',TRUE,TRUE,''),
('Amberly Place','6 - Passed','Tampa-St. Petersburg-Clearwater, FL',770,1991,181818,140000000,NULL,'2024-09-25','2025-05-15','All Docs Saved - Jay,  Hope all is well and you enjoyed the Open. Amberly Place is a great property.  Completed in 1991, concrete construction, all two-story product with ground-floor private entry. Awesome location in affluent Tampa Palms. Pricing probably in the low $140mil+ range.  Did you look at Fisherman’s Village in Orlando??',TRUE,TRUE,''),
('Altis Santa Barbara Apartments','6 - Passed','Naples, FL',242,2024,384297,93000000,NULL,'2025-05-07','2025-05-15','For Tracking PP - All Docs Saved Guidance on Altis is $93-$95M. Remember that Naples has very low millage rate of 10.2 as compared to double that along the east coast. This is great product with a mix of traditional Altman 3-story walkup with the direct access garages and 5-story elevatored product.',TRUE,TRUE,''),
('Cortland Windward','6 - Passed','Atlanta, GA',294,1987,261904,77000000,'2025-05-15','2025-03-21','2025-05-15','All Docs Saved -

Ethan— 

We just launched the OM.  CFO is in 30 days.  Couple of things to note:

Location:
Perhaps best location in entire Atlanta MSA. 
Walkable to Alpharetta City Center and Avalon and Fiserv
Next door to Alpharetta’s best Elementary School
Severe supply constraints (most restrictive in Atlanta)


Asset:
Restored-to-Core w/ $48,000/door of interior/exterior upgrades
Only 3 Class B assets in all of Alpharetta, limits renters seeking “value” options 
Only asset with direct access (no breezeways) and Townhome units

Opportunity:
Over 100 basis points of yield growth attributable to:

-“Return to Peak Rents” underway with new leases showing 4.8% growth (+$282,000)
-Only 10% penetrated on new Bulk Cable/Internet (+$146,000)
-Opportunity to implement valet trash (+$52,000)
-Opportunity to build 40 garages at $200/mo (+$96,000)
-Opportunity to build 50 gated backyards at $200/mo (+$120,000)
-Opportunity to increase rents and still trail new construction by substantial amount

Anticipate pricing in low to mid $260,000/door equating to going-in 5% cap, tax adjusted.   

I am touring this Thursday and Next Thursday.  Are you able to coordinate a tour?


Cortland has fully renovated',TRUE,TRUE,''),
('The Place On Millenia Boulevard Apartment Homes','6 - Passed','Orlando, FL',371,2007,225067,83500000,'2025-05-14','2025-04-14','2025-05-15','All Docs Saved - Ethan,

Ask on Place on Millenia is $83.5M or $225K per door, which is a 5.2% T3, tax and insurance adjusted cap rate and a mid/upper 5% year 1.

The Property is a well-maintained, 3-story garden asset with 50%+ of the unit mix featuring original interior finishes and renovated units that have been achieving $150-$200 rent premiums for upgraded kitchens, baths, and flooring. Additionally, current ownership has been focusing on occupancy (97% currently and over 95% on the T12) and not pushing rents as much on tradeouts or renewals, so there is a strong opportunity for new ownership to increase the renovation premiums and draft off of the newer nearby comps which are achieving rents $300+ higher.

The Property is located 10 minutes the new Epic Universe theme park (15K new jobs coming next month), Lockheed Martin, and Universal Orlando which account for 50K+ immediate jobs. Additionally, residents have less than a 5 minute commute to over 2.5M SF of destination retail in and around the Mall at Millenia.

Please let us know what questions you have as you review or if you would like to schedule a tour of the Property.',TRUE,TRUE,''),
('Kessler Point','6 - Passed','Savannah, GA',120,1990,NULL,NULL,NULL,'2025-03-24','2025-05-15','Coming Soon - 1/3 in Sav Portfolio $60MM Total',TRUE,TRUE,''),
('The Arbors Apartments','6 - Passed','Savannah, GA',108,1988,NULL,NULL,NULL,'2025-03-24','2025-05-15','Coming Soon - 3/3 in Sav Portfolio $60MM Total',TRUE,FALSE,''),
('Azure Cove','6 - Passed','Savannah, GA',144,1987,NULL,NULL,NULL,'2025-03-24','2025-05-15','Coming Soon - 2/3 in Sav Portfolio

$60MM Total',TRUE,FALSE,''),
('Cortland Decatur East','6 - Passed','Atlanta, GA',378,2020,235449,89000000,'2025-02-26','2025-01-22','2025-05-15','All Docs Saved - Ethan – Thanks for reaching out.
 
Pricing is $220K/unit (multifamily) and $15K/unit (25K SF retail) for a total price of $89M ($235K/unit). This is a 5.48% trailing cap rate based on T3 Income / Tax-Adjusted Expenses. 
 
This asset is 40%+ below replacement cost—highly attractive basis for 2019 wrap product developed by Cortland.
 
Supply/demand dynamics in the Decatur submarket are the best in infill Atlanta, with no competing properties in lease-up and only one property under construction.. 
 
The property is performing well at 94% occupancy with positive trade-out’s.
 
When are you available to discuss?',TRUE,TRUE,''),
('Alta Northerly','6 - Passed','Atlanta, GA',310,2024,NULL,NULL,NULL,'2025-01-27','2025-05-12','All Docs Saved - Good afternoon, Ethan.  

Pricing guidance is $280’sK/unit which is below replacement cost given the challenging entitlement environment and superior schools.  We are guiding to a low 5% YR1 cap rate.  A few other notes on the opportunity.
 
1.	Forsyth County features the Atlanta MSA’s best public schools, is Georgia’s wealthiest county, and was voted the #1 best county in Georgia to live in.
2.	Low density garden style one- and two-bedroom apartment homes on 50+ acres with an expansive resort style amenity set.
3.	Unit Finishes are high quality, featuring 9’ & 10’ ceilings, gas ranges, granite countertops, and stainless appliances.  
4.	Alta Northerly is ideally positioned for rent growth given that Forsyth County has the highest ratio of population growth to MF units under construction in Atlanta.
5.	Last month, Board of Commissioner’s approved a moratorium on all residential housing applications to help ensure the elite school system is protected in the face of high population growth.  
6.	Last note….these demos are so good.  Falls hadn’t had an eviction in 4+ years and had positive bad debt.  Alta Northerly is just like it in that it has never had an eviction or rent losses.  
 
A large part of what makes this investment so compelling (beyond the scarcity and challenges of building here) involves taxes. Millage rates are exceptionally low in Forsyth and has been decreasing due to the appreciation of property values in the area.  The millage rate in Forsyth County has decreased 11% in the past 7 years and is now only 24 mills per thousand: 30 to 40% less than other metro Atlanta counties. 
 
 Let’s put a time on the calendar for me to review the story with you over zoom/teams.  We had started the marketing process a few weeks ago on The Falls at Forsyth (located adjacent to Alta Northerly) and it got preempted by an institutional investor.  The GA-400 corridor is dynamic.',TRUE,TRUE,''),
('Uptown Villas','6 - Passed','Tampa-St. Petersburg-Clearwater, FL',60,2004,NULL,NULL,NULL,'2025-05-09','2025-05-12','All Docs Saved',FALSE,TRUE,''),
('The Atlantic Briarcliff','6 - Passed','Atlanta, GA',214,1986,196261,42000000,NULL,'2025-05-01','2025-05-12','All Docs Saved  - Good morning, Ethan.  I hope all is well. 

Pricing is in the high $190’s to low $200’s/unit, cap rate between 5.25%-5.5%. 

Let us know if you want to schedule a property tour and/or discuss further.',TRUE,TRUE,''),
('The Shaw','6 - Passed','Washington, DC-MD-VA',69,2020,391304,27000000,NULL,'2025-05-01','2025-05-09','All Docs Saved - Ethan,
 
Glad to see that you’re taking a look at this.  We are targeting $27m for this deal which is a blended 5.85% cap rate on proforma and a 5.3% cap rate on in-place.  The property also has ground level retail and has one retail tenant and two vacant retail bays.  The breakout in pricing is roughly $355k per unit for the multifamily and approximately $3m for the retail.  The property generally is a core buy but I think a play here is to convert the some or all the vacant retail space to amenities for the apartments.  We have seen this done on other properties with much success and would likely raise the property profile and rental rates by $150 per month across the board.  The in-unit fit outs are outstanding.    Happy to discuss in greater detail if needed.
 
Hope all is well and look forward to speaking with you soon.',TRUE,TRUE,''),
('Venture at Long Shoals','6 - Passed','Asheville, NC',86,2024,267441,23000000,NULL,'2025-04-28','2025-05-09','All Docs Saved - Hey, Ethan. Hope all is well and thank you for reaching out. Venture at Long Shoals is a very unique, in-fill boutique community in South Asheville that recently hit stabilization. Pricing guidance is in the mid-$20Ms, or ~$270s/u, which is a FY1 mid-5% cap. One item to note is that the property received tax abatement from the City of Asheville for 17 years which helps to boost the return profile.
 
We will be relaunching this week with the full OM and Document Center.',TRUE,TRUE,''),
('Park Central North Hills Apartments','6 - Passed','Raleigh-Durham-Chapel Hill, NC',286,2017,454545,130000000,NULL,'2025-05-05','2025-05-09','All Docs Saved  - $130M - $100M for Multi and $30M for Retail

•	Multi - $100M | $350K/u | 4.75 in-place
o	April lease tradeouts averaged 6.5+%
•	Retail - $30M | $740/ft | 6.25 Yr1
o	Recent leasing at $50 psf NNN
•	Attractive Assumable Debt – Pacific Life
o	15-year, full-term IO at 4.37% through March 2034',TRUE,TRUE,''),
('Alta Biltmore','6 - Passed','Phoenix-Mesa, AZ',215,2024,348837,75000000,'2025-05-19','2025-04-16','2025-05-08','All Docs Saved - Jay – Guidance is $75-$77M',TRUE,TRUE,''),
('APEX South Creek','6 - Passed','Orlando, FL',300,2021,260000,78000000,'2025-05-20','2025-03-19','2025-05-08','All Docs Saved - 
Hi Ethan – Hope you had a nice weekend, thanks for reaching out. 

We’re targeting the upper $70 / low $80 millions range on APEX, or $260,000 - $270,000 per unit. This works out to a low 5s in-place cap rate on T-3 numbers at 95% occ. (tax adj.), ramping to mid-5s territory in FY1.  The buyer here will have the option to assume the in-place agency loan (Freddie Mac) with about 7 years of term remaining.  Current loan balance of ± $46 million, 5.48% fixed rate, and roughly 2.5 years of I/O left. 

No CFO date has been scheduled yet, but we’d anticipate offers being due around mid/late May timeframe. 

We’re happy to hop on a phone call to share more of the backstory here.  Keep us posted with any questions in the interim, or if you’d like to schedule a tour of the community.  


DR Horton built
-	Guidance will be more like ~$80MM now…
-	Management is bad… same story as Metro, occupancy and bad debt issues
-	Could be interesting',TRUE,TRUE,''),
('Avana Acworth','6 - Passed','Atlanta, GA',240,2001,191666,46000000,NULL,'2025-05-01','2025-05-08','All Docs Saved -
Thank you for your interest in Avana Acworth. Few opportunities like this come to market in the northern suburbs of Cobb County so you will want to focus here.

 

Curb appeal is excellent as is the general condition of the community. We are guiding to around $190K per unit/approximately $46 million which translates to a mid 5% cap rate based on recent trailing numbers tax adjusted.

 

Greystar owns and operates the property. We expect the CFO at the end of May and you will be notified in advance.

 

A few things to consider:

 

High-quality product with no deferred maintenance – Current ownership has invested over $3.2m into the property over the last 5 years
Elite Cobb County School District: Zoned for A rated North Cobb High School
Average resident annual income of $101,500 and rent-to-income of 18% provides ability to absorb higher rents
Primed for Value add program: Unit Mix consists of 17% classic and 83% partially renovated
When would you like to schedule a tour?',TRUE,TRUE,''),
('Optimist Lofts','6 - Passed','Atlanta, GA',218,2008,204128,44500000,'2025-05-06','2025-04-08','2025-05-08','All Docs Saved -  Ethan,
 
Thanks for reaching out.
 
Guidance on Optimist Lofts is $44.5M, or $209K/unit (the prior sales price was $57M, or ~$270K per unit). The lender took over the property roughly one year ago and has invested heavily in deferred maintenance and capex, such as brand-new TPO roofs, extensive lighting improvements, elevator repairs, etc.
 
The lender has also focused heavily on operations, increasing the property''s economic occupancy from the low 60% range to the low 90% range. Additionally, they have cleared out nearly all non-paying tenants and brought all units back to rent-ready condition. This sets the stage for new ownership to focus on revenue-generating projects, like interior renovations, with only 7 units having been renovated thus far.
 
The immediate location has also been the beneficiary of substantial recent investment. For years, this location has been “in the path of progress”, which has now come to fruition. A national developer is building Class A+ apartments in the immediate area, targeting rents over $600 higher than Optimist Lofts and the Atlanta Beltline is connecting directly across the street. 
 
Currently still owned and operated by the lender, there is a great opportunity for new ownership to further improve operations and take Optimist Lofts to the next level.
 
Please let us know if you’d like to schedule a tour or quick call to discuss.',TRUE,TRUE,''),
('Altis Grand Suncoast Apartments','6 - Passed','Tampa-St. Petersburg-Clearwater, FL',449,2024,305122,137000000,NULL,'2025-04-30','2025-05-08','For Tracking PP - All Docs Saved - Altis Grand Suncoast - 305k/door
Altman developer',TRUE,TRUE,''),
('The Landing at Stone Chimney','6 - Passed','Wilmington, NC',121,2025,280991,34000000,NULL,'2025-04-22','2025-05-08','All Docs Saved Stone Chimney: $280k per home / 6.15% stabilized cap rate (signed leases of $2,351, no rent growth, 1 month of concessions, stabilized expenses)',TRUE,TRUE,''),
('The Arboretum at Brunswick Village','6 - Passed','Wilmington, NC',230,2025,278260,64000000,NULL,'2025-04-22','2025-05-08','All Docs Saved  -Arboretum: $280k per home here, 6.10% stabilized cap rate (signed leases of $2,232, no rent growth, 1 month of concessions, stabilized expenses)',TRUE,FALSE,''),
('Gainesville Portfolio','6 - Passed','Gainesville, FL',1432,1985,164106,235000000,NULL,'2025-05-07','2025-05-08','For Tracking PP - 6 props - for a rainy slow day - EJ
4.5% mgt fee

$235MM

hunter crossing - 56MM
lake crossing - 47M
Huntington lakes - 54M
lakewood villas - 32M
woodland villas - $9M
spyglass - $37.5M

They put of capex items in R&M, 66% renovated units',FALSE,TRUE,''),
('Mosby Steele Creek','6 - Passed','Charlotte-Gastonia-Rock Hill, NC-SC',272,2023,257352,70000000,'2025-05-07','2025-04-08','2025-05-08','All Docs Saved - We’re guiding $260k/unit which is a 5.2% cap rate (carrying 2% concessions). CFO is Wednesday May 7th. 

The asset is 2-story, low density product with fenced in yards on 76 units. It lives more like a BTR asset than conventional garden. The submarket has extremely high barriers to entry which has led to 0 multifamily units under construction. 

I’ve provided some additional details below, but let us know if you would like to schedule a call or tour. 

Mosby Steele Creek | 2024 Vintage | 272 Units 
•	Address: 13511 Montoy Way, Charlotte, NC 
•	272 Units / 1,000 Avg SF / $1,652 Avg In-Place Rent / $1.65 PSF
•	86% Occupied / 89% Leased – Initial move-ins were October 2023 (Buildings 8-10) with the remaining 7 buildings delivering between December 2023-Feburary 2024. Absorption has averaged ~16 units per month over the trailing 12 months with expected stabilization in early Q2 2025
•	Super differentiated, low-density two-story product (10.7 units/acre)
o	Fenced-in yards on 76 ground-floor units
o	Smart thermostats (only deal in the submarket)
o	Onsite walking trail and oversized dog park (largest in the submarket) 
•	Adjacent to Lake Wylie Elementary School (7/10)
•	Major operational upside through managerial continuity and mark-to-market on second-gen leases
o	Turnover of previous managers and staff presents opportunity for optimizing efficiency, tenant satisfaction, and overall property performance
o	Heads-in-beds strategy presents large mark-to-market opportunity on legacy leases evidenced by 4%+ top-line rent growth since summer of 2024. 
•	The Steele Creek submarket poses extremely high barriers-to-entry primarily rooted in the NIMBYism of the Steele Creek Residents Association (SCRA)
o	SCRA plays a key role in new development approval with a strong voting presence that influences elected officials
o	Their review imposes additional requirements throughout the approval process leading to strenuous and elongated pre-dev process
?	SCRA was responsible additional development parameters for Mosby Steele Creeks such as maximum two-story height restriction, turn lanes on Erwin Road and Steele Creek Road, and extensive landscaping and fencing along South Tryon Drive.
•	Steele Creek has one of the most favorable supply dynamics in the Charlotte metro
o	Under construction supply in Steele Creek represents just 2.99% of the existing inventory, ranking 2nd best across Charlotte’s 17 submarkets
o	70% decline in supply by 2026 – 0 assets U/C within a 3 mile radius 
•	Highly amenitized suburban location with 1.2M SF of retail within 1 mile radius including 6 individual grocers such as Sprouts, Publix, Harris Teeter, and Target',TRUE,TRUE,''),
('The Darnell Apartments','6 - Passed','Atlanta, GA',246,2023,239837,59000000,'2025-05-13','2025-04-11','2025-05-08','All Docs Saved - Thanks for reaching out and happy to help. 

 

Guidance on The Darnell is at $239k/ unit which represents a 5.5% cap on in place rents adjusted for 95% occupancy. This does NOT include the 25 bps due to the tax lock throuh 2026.  


Few quick notes for your underwriting:

Rents have a $214+/unit gap with nearby Norcross Competitors
$272,000+ low-hanging-fruit income upside
Demographics of $107,000+ for onsite residents
Projected zero new Norcross Supply for foreseeable future
 

Offers are due on May 13th and we will be touring on Thursdays. Are you available this Thursday, April 17th, for a tour?',TRUE,TRUE,''),
('Parc 85 Duluth','6 - Passed','Atlanta, GA',344,2002,229651,79000000,'2025-05-21','2025-04-21','2025-05-08','All Docs Saved - Good afternoon, Ethan, and Jay.  

Parc is in really good condition and is performing well – 96% occupied, bad debt +/- 1%, 0 to minor concessions on select units, and right side of supply going forward. 

A few highlights: 
•	44% classic units (150 units), with ability to renovate and push rents $250+/unit - ($490k in revenue upside)
•	Owner’s “reno” is just mediocre, leaving plenty of upside with market comps proving out another $300/unit - (at $200/unit, $465k in revenue upside)
•	Projected rent growth for next three years – 3%+/year
•	236 units without washer and dryers – ($100k in revenue upside)

The owner is a market seller and doesn’t want to put price on the property currently. 

I hope this helps. Let us know if you want to schedule a property tour soon and/or discuss in greater detail. 

Derrick',TRUE,TRUE,''),
('Somerset Bay','6 - Passed','Tampa-St. Petersburg-Clearwater, FL',144,2025,263888,38000000,NULL,'2025-04-30','2025-05-08','DR Horton Forward Sale 
All Docs Saved - Hey Ethan,

Great to hear from you. We’re expecting around $265-275k per home here, which equates to 6.5-6.75% stabilized cap rate. First homes are expected in October 2025 with a delivery pace of 10-15 homes/month.

The property will feature a mix of 3-, 4-, and 5-bedroom homes complete with concrete block construction, two-car garages and two-car driveways, and private fenced yards. We have put forth a proposed unit mix in the OM, but you can amend the unit mix if you’d like.

As part of the larger Somerset Bay community, the property will be the only dedicated BTR asset within a master-planned community of 1,750 total homes. It also enjoys a central location within rapidly growing Spring Hill, proximate to retail, employment, and just a 50-minute drive to Tampa.

Note the property will be subject to CDD O&M payments of $850/home annually. However, this is a key selling point of the property as residents will have access to the larger community amenities within Somerset Bay, which will include a clubhouse, pool, playground, pickleball courts, and dog park.

Please let me know if you have some time to jump on the phone to discuss.',FALSE,TRUE,''),
('Avana Stoney Ridge','6 - Passed','Washington, DC-MD-VA',264,1985,257575,68000000,'2025-05-13','2025-04-02','2025-05-08','All Docs Saved - Guidance is $68mm. 5.25% Cap in-place.',TRUE,TRUE,'')
ON CONFLICT (name) DO NOTHING;

INSERT INTO deals (name,status,market,units,year_built,price_per_unit,purchase_price,bid_due_date,added,modified,comments,flagged,hot,broker) VALUES
('Tavalo Tradition BTR','6 - Passed','Fort Pierce-Port St. Lucie, FL',216,2024,347222,75000000,'2025-05-15','2025-04-08','2025-05-08','All Docs Saved - 
Hey Ethan – Hope you’re doing well, appreciate you reaching out.  

Our pricing target is ± $75 million ($345K - $355K per unit range, or about $240 psf), which is a 5.25% cap rate on the current rent roll (at stabilized occupancy), ramping to 5.5% territory in FY1. 

Beautiful new townhome community completed last year by K. Hovnanian as the builder.  Overall, Tavalo stands out as one of the most impressive, core-quality build-to-rent development executions to-date here in Florida, with several unique elements that set it apart from the lion’s share of existing inventory across the state:

•	Picturesque streetscape with all townhomes featuring a rear-loaded two-car garage design – a rare find in Florida BTR communities due to the higher construction costs compared to standard front-load design
•	Deep amenity footprint with a spacious clubhouse, fitness center, resort-style pool & sundeck, pickleball courts, dog park, children’s playground, etc. 
•	Overall site plan with wider streets, deeper setbacks & expansive landscaping package (maintained by HOA) is much more representative of a luxury “for-sale” community vs rental 
•	216 units represents sizeable scale in the BTR space (average unit count for Florida BTR = ± 125 units).  Less than 20% of Florida BTR communities boast unit counts of 200+ – the majority of which are cottage-style / horizontal multifamily product. 

The community is currently ± 86% leased, anticipated to reach initial stabilization in the coming months, prior to time of closing.  Given the community’s unique appeal and rapid growth of the surrounding Tradition master plan, both tour traffic & leasing velocity have outperformed the majority of the market nationally, averaging 47 prospective resident tours and 18 leases (gross) per month from Jan-24 thru Mar-25. 

No CFO date has been established as of yet, but we’d anticipate offers being due around mid-May timeframe.  

We’re happy to hop on a phone call to share more of the backstory here.  Keep us posted with any questions in the interim, or if you’d like to schedule a tour of the community.',TRUE,TRUE,''),
('1800 Ashley West Apartments','6 - Passed','Charleston-North Charleston, SC',209,1980,205741,43000000,'2025-05-27','2025-04-22','2025-05-08','All Docs Saved - Ethan,
 
Good to hear from you! Thanks for your interest in 1800 Ashley West, a 209 unit / 1980 vintage multifamily asset in the West Ashley sub-market of Charleston, SC. 1800 Ashley West provides investors with day one cash flow, plus the opportunity to implement a “value-add 2.0” program. 
 
The asset’s premier location in the supply-constrained submarket of West Ashley, coupled with an in-place tax abatement, a rich set of amenities on site, and minimal CapEx needs, provides an enticing opportunity for the next owner. At pricing guidance, the property is offered $70k/unit below replacement cost to today’s current cost of construction.  
 
Please review the information below and in our OM and let me know a good time for a call to discuss. Thanks! 
 
----------  
 
1800 Ashley West | 209 Units | 1980 YOC | Charleston, SC
 
Property Address:  
1800 William Kennerty Dr, Charleston, SC 29407  - Map Link
 
Property Tours:  
Offered with 48-hours advance notice. Please contact our team to schedule a tour. 
 
Call for Offers Date:  
Tuesday, May 27th, 2025 
 
OM & DD Docs:  
OM (coming Thursday), T12, rent roll, assumable loan info, etc. located here (Click "View the Agreement” to sign NDA): Link to CA and Deal Room
 
Pricing Guidance:  
±$205K/per door (~$43MM) offered free and clear. 
 
Down Units – 16 Due to Fire:
Currently, there are 16 (1 BR) down units in the building at the front of the property, due to fire damage. The seller has received confirmation of insurance proceeds, which will be assigned to the buyer at sale. The proceeds will cover a restoration down to the studs, with ample insurance proceeds to rebuild luxury-style units. They will also cover loss of rental income from the units while they are being rebuilt, with those proceeds also assigned to the buyer post-sale.',TRUE,TRUE,''),
('Bayshore Landing Apartments','6 - Passed','Baltimore, MD',158,1984,246835,39000000,NULL,'2025-04-08','2025-05-08','All Docs Saved - Ethan – Great running into you last week!! 

Looking for +/- $39mm at Bayshore.',TRUE,TRUE,''),
('The Pointe at Midtown','6 - Passed','Raleigh-Durham-Chapel Hill, NC',365,1970,NULL,NULL,NULL,'2025-04-29','2025-05-07','ZOM All Docs Saved',TRUE,TRUE,''),
('Bell at Broken Sound Apartments','6 - Passed','West Palm Beach-Boca Raton, FL',270,2018,466666,126000000,'2025-05-15','2025-04-16','2025-05-07','Tracking PP -  All Docs Saved  - Ethan…Target is $470k per unit. Thanks.',TRUE,TRUE,''),
('Neely Village Towns','6 - Passed','Greenville-Spartanburg-Anderson, SC',69,2023,289855,20000000,NULL,'2025-04-22','2025-05-07','All Docs Saved - Hey, Ethan!

This is an opportunity to acquire a 69-home, luxury, build-to-rent community at a significant discount to retail (~16% discount to nearby TH sales). 
 
Neely Village delivered in 2023 and has recently stabilized providing the opportunity to push rents on renewals and new leases. The community consists of 3-bedroom, individually platted, 2-story townhomes, each with their own attached 1-car garage, smart home technology, hard surface flooring throughout, and pristine interior finishes. 

Located less than 20-minutes from DT Greenville, residents have an easy commute to employers within the Greenville MSA. Residents also have access to a plethora of nearby amenities including a Publix Anchored Mauldin Square Shopping Center. 
 
Guidance is ~$295k/home, targeting a ~5.7% FY1 cap rate.
    
Investment Highlights
•	Beautiful, New Construction Townhomes with Attached 1-Car Garages 
•	Significant Discount to Retail Home Values (~23% discount to zip code cost of home ownership & ~48% discount to Greenville MSA home ownership)
•	Exceptional Retail and Entertainment Amenities within Walking Distance (<1-min to Maulin Square Shopping Center)
•	Immediate Access to Top-Tier Public & Private Education Institutions (>A avg. Niche Rating Elementary, Middle, and High School)
•	Superior On-Site & Submarket Demographics Provide Ample Rental Upside in Short-Term & Long-Term ($140k avg. HHI at the property)
•	Outsized Greenville MSA Rent Growth Projections (3.25% avg. projected rent growth over next 5 years)

Thanks,',TRUE,TRUE,''),
('Summers Point Apartments','6 - Passed','Phoenix-Mesa, AZ',164,1980,152439,25000000,NULL,'2025-04-28','2025-05-07','All Docs Saved  - Jay, guidance is $25M which is an in-place 5.65% cap.  Let us know if you would like additional color.',TRUE,FALSE,''),
('Cantala','6 - Passed','Phoenix-Mesa, AZ',184,1986,206521,38000000,'2025-05-08','2025-04-24','2025-05-07','All Docs Saved - $38MM',TRUE,TRUE,''),
('Camden Copper Square Apartments','6 - Passed','Phoenix-Mesa, AZ',332,2000,256024,85000000,'2025-05-06','2025-03-26','2025-05-07','All Docs Saved - $85MM',TRUE,TRUE,''),
('Desert Horizon Apartment Homes','6 - Passed','Phoenix-Mesa, AZ',514,1988,252918,130000000,'2025-05-07','2025-04-14','2025-05-07','All Docs Saved  - $130MM',TRUE,FALSE,''),
('2nd Avenue Commons','6 - Passed','Phoenix-Mesa, AZ',144,2023,277777,40000000,NULL,'2025-04-30','2025-05-07','All Docs Saved - 2nd Avenue Commons
-	Mesa
-	~40M guidance gcost 330 to build
-	4 deals leased up same time so may be a mark to market
-	New deal',TRUE,TRUE,''),
('Bower Hudson Crossing','6 - Passed','Phoenix-Mesa, AZ',43,2024,534883,23000000,NULL,'2025-05-05','2025-05-07','All Docs Saved - $23m +/-',TRUE,TRUE,''),
('Sherwood Crossing','6 - Passed','Baltimore, MD',636,1988,259433,165000000,NULL,'2025-04-29','2025-05-05','For Tracking -  +/- $165mm. 5.9% Cap in-place.',TRUE,TRUE,''),
('Revel Apartments','6 - Passed','Washington, DC-MD-VA',500,2022,470000,235000000,NULL,'2025-04-30','2025-05-05','For Tracking All Docs Saved - 
Ethan,
 
Good to hear from you.  We’re targeting $235m for the deal which is a 5.5% cap on profoma and a 5.25% cap on in place.  The quoted pricing & cap rates are on a blended basis with the apartments, retail & garage parking.  The property is one of the best amenitized properties that I’ve worked on and has been pushing rents now that much of the market has been leased up.  The retail is largely leased at this point and all of the ancillary bays along 1st Street are either in contract negotiations or are under LOI.  Let me know if you would like to setup a call to discuss the property in greater detail.  Here is a link to my calendar to help us find a time to speak - https://calendly.com/jorge-rosa-cushwake/c-w-mid-atlantic-catch-up',TRUE,FALSE,''),
('Channel Square','6 - Passed','Washington, DC-MD-VA',231,1968,225108,52000000,NULL,'2025-03-19','2025-05-05','All Docs Saved - Hey Ethan,Guidance is $52M. 

JS: navy yard, older, looks ok',TRUE,TRUE,''),
('Ellicott House','6 - Passed','Washington, DC-MD-VA',327,1974,214067,70000000,NULL,'2025-02-14','2025-05-05','Off Market / Coming Soon from JLL
"around 70M" (saw with Bobby ~100M)',TRUE,TRUE,''),
('Annex at Cadence BTR','6 - Passed','Phoenix-Mesa, AZ',135,2025,385185,52000000,'2025-05-01','2025-03-25','2025-05-05','All Docs Saved -  Annex at Cadence Deal Pitch Email:
Thank you for your interest in Annex at Cadence, a 135-home, Build-to-Rent community featuring attached townhome-style homes with direct access two-car garages and private patios. (CA: RCM Deal Room Link). Annex at Cadence is a one-of-a-kind opportunity to purchase a Class-A product in Eastmark, Mesa – one of the top submarkets in the Southeast Valley. More details on the offering below: 
•	Guidance: $52,000,000 (±$385,185/unit)
•	Tours: Please reach out to Emily Leisen to schedule onsite tours
•	Financing: Please reach out to Brandon Harrington and Bryan Mummaw to discuss new financing options 
•	Call for Offers: To be announced 
 
 
Deal Highlights: 
•	Prime Location: Within Cadence Homeowner’s Association, offering resort-style amenities such as a spin room, tennis courts, lap pools, yoga/barre studio, and more
•	Operational Upside: Currently self-managed by the original developer, presenting an opportunity for efficiency gains via third-party management.
•	HOA Advantage: Residents pay $100/unit/month, covering landscaping, exterior maintenance, sidewalks, streets, and more, reducing owner expenses.
•	Luxury Interiors: Three-bedroom, farmhouse-style homes with 9’ & 10’ ceilings, granite countertops, ceramic plank tile flooring, stainless steel appliances, kitchen backsplashes, walk-in showers, dual vanity sinks, large kitchen islands, full-size Samsung washers/dryers, and more.
•	Limited Competition: High barriers to entry—only two multifamily properties under construction within a 3+ mile radius.
•	Affluent Demographics: Nearby average home prices of $704K - $811K, creating a favorable rent vs. own gap.
•	Top-Ranked Master-Planned Community: Eastmark was Arizona’s #1 best-selling community in 2023 and ranks among the nation’s top-selling master-planned communities (RCLCO).
•	Strong Lease-Up Trajectory: Currently 100% occupied (excluding two model units).
 
Cadence at Gateway Association Amenities: Residents have access to the following:
 
•	Heated Resort-Style Pool with Twisting Chute Waterslide 
•	Additional Lap Pool 
•	Jacuzzi 
•	Community Spa Area with Modern Decor, Lounge Chairs, Cabanas, and Fire Pit 
•	Moto Fitness Center fully equipped with free weights, treadmills, elliptical trainers, and other equipment 
•	Spin Room with Cycling Machines 
•	Yoga and Barre Studio 
•	Flourish Community Center with a Resident Lounge, indoor/outdoor space for gatherings 
•	Game On Studio with Arcade Games including Pinball and Foosball 
•	Stir Business Center and Coffee Bar 
•	The Mix Event Center/Gathering Space with AV and Large Patio 
•	6 Parks 
•	Playground Pavilion 
•	Sport Courts including Basketball, Sand Volleyball, Tennis, and Bocce Ball 
•	Dog Park
 
 
Location Highlights: Affluent Location with Outstanding YoY Population Growth and Nearby Several Major High-Wage Employment Centers
•	66% white-collar workforce | Projected 16%+ job growth | $166K avg. household income
•	Next to Elliot Road Technology Corridor (40+ companies: Amazon, Meta, Google, Apple, AWS, NTT, Comarch)
•	Walking distance to Cadence Parkway Retail (Black Rock Coffee, Jersey Mike’s, Ace Hardware, Mountainside Fitness, Bosa Donuts & more)
•	Near major retail hubs: Gilbert Gateway, Cooley Station, SanTan Village, Epicenter at Agritopia
•	2 miles from Arizona Athletic Grounds (formerly Legacy Sports Park) with 24 soccer fields, 20 volleyball courts, 40 pickleball courts, and a 64-court indoor facility
•	Close to ASU Polytechnic Campus (6,000+ students, 200+ faculty & staff)
•	Minutes from Phoenix-Mesa Gateway Airport (4,000+ jobs, $1.8B economic impact annually)
•	Near $5.5B LG Battery Plant (4,000+ new jobs expected by 2026)
•	10 miles from 480,000+ jobs | Easy access to Loop 202 & major employment hubs
 
Economic Drivers (within 5-20 minutes of the property):
•	Arizona Athletic Grounds
•	ASU Polytechnic Campus
•	Mesa Gateway Airport 
•	Apple Data Center 
•	LG Data Center 
•	Meta Data Center
•	Banner Desert Medical Center 
•	Elliot Road Technology Center 
•	Price Road Employment Center 
•	Chandler Airpark 
•	Cadence Parkway Retail Center
•	Gilbert Gateway Town Center
•	Cooley Station',TRUE,TRUE,''),
('Cortland La Villita','6 - Passed','Dallas-Fort Worth, TX',306,2006,238562,73000000,NULL,'2025-05-02','2025-05-02','All Docs Saved - 240 unit',FALSE,TRUE,''),
('Cortland Legacy','6 - Passed','Dallas-Fort Worth, TX',395,2014,227848,90000000,NULL,'2025-05-02','2025-05-02','All Docs Saved - 230/unit',FALSE,TRUE,''),
('Cortland Oak Lawn','6 - Passed','Dallas-Fort Worth, TX',368,2015,239130,88000000,NULL,'2025-05-02','2025-05-02','All Docs Saved  - 240k/unit',FALSE,TRUE,''),
('Cortland Prairie Creek','6 - Passed','Dallas-Fort Worth, TX',464,1998,284482,132000000,NULL,'2025-05-02','2025-05-02','All Docs Saved - 285k/unit',FALSE,TRUE,''),
('841 Memorial Apartments','6 - Passed','Atlanta, GA',80,2016,225000,18000000,'2024-10-01','2024-08-23','2025-05-02','All Docs Saved - Jay, price guidance is mid-to-upper $220k/unit ($18M+), which is a low-5% adjusted, in-place cap rate. Boutique, 80-unit property built in 2016 directly on Memorial Drive and the Eastside Beltline
Accretive assumable loan with 4.00% rate (see data site for more details)
9’ and 10’ ceilings with quartz/stainless finishes; amenities: rooftop deck, dog park and fitness center
Immediate access to Beltline, Madison Yards (Publix), The Eastern music venue and much more. We have also launched Bass Lofts (5 minutes away) for the same seller. This is an old high school converted to residential in Little Five Points – really cool deal. Price guidance is approaching $260k/unit (mid-$30M+/-).',TRUE,TRUE,''),
('Estates at Lake Cecile','6 - Passed','Orlando, FL',72,2014,298611,21500000,'2024-11-21','2024-11-07','2025-05-01','All Docs Saved -  Ask is $21.5M/$298K per unit / $185 PSF.  Going in cap rate is a 5.5% on in-place income and buyer expenses, adjusted for taxes and insurance, and year 1 is a mid-6%..  There is a ton of upside with this one and a clean deal to start.  The property is a gated community with true 2-story townhome units.

 

Upside:

There is a ton of room to move rents.  Nearby comps are averaging $3,200 for renovated units.  Current in-place rents at Estates are $2,435.  See page 10 of the OM for rents and upside
Current ownership isn’t charging for trash, quick upside to implement a charge back program
Current ownership isn’t charging for cable/internet.  Opportunity to implement a charge back program
There is currently a 4-bedroom model on-site that isn’t needed.  Opportunity to convert that into a rentable unit for an immediate $35,000 of additional revenue
Renovation recommendations to compete with nearby comps:
Interior upgrades to the current partial/light renovated units - shaker cabinet fronts, hard-surface counter-tops with undermount sink, tiled backsplash and vinyl plank flooring throughout
Interior upgrades to the classic units – full scope
Fresh landscape package
Light pool updates; lounges and a sunshade
Add a dog park
Update sport court
Opportunity to start charging for water views

Jay,

 

Wanted to send over this detailed outline of the VA story as you dive in.  Let me know if you would like to schedule a call or tour.

 

Property Highlights:

Large true 2-story townhome units within a gated community
Well-maintained property with only two floorplans, large 3/3’s (1,508 SF) and 4/3’s (1,712 SF)
Low density product with a lake and a pond on either side of the property
Current ownership has spent $500,000 on CAPEX (interiors, light exterior upgrades)
Excellent area – 5 miles from AdventHealth Celebration, Kissimmee Airport and The Loop
Make sure to underwrite the property with your expenses.  The seller is a small private seller and comes from the manufacturing home space
 

Value-add:

Renovations:

Significant opportunity to renovate 100% of the units to a premium scope:
100% of the units have older brown cabinets, older tile flooring throughout, formica countertops with older plumbing fixtures.  These are the main finishes of the kitchen and baths which makes the interiors feel outdated
Seller has completed 44 units with SS appliances, white paint, new carpet, and vinyl plank in a small section on the first floor, light fixtures, and fans
Seller has completed 16 units with white paint, new carpet, and vinyl plank in a small section on the first floor, light fixtures, and fans
There are 12 classic units
Substantial upside to renovate all units with a renovation program to demand significantly higher rent premiums
Buyer has the opportunity to add – shaker style cabinet fronts with painted boxes, quartz counter-tops with under-mount sink, tiled backsplash, carry the vinyl plank flooring throughout the first floor and to the bedrooms
Modernizing the units to the above scope will compete with the immediate area comps with significantly higher rents.
Immediate area comps with similar size renovated/new units are achieving high $2,800 / low $3,000 in rents.  Several hundred more than Estates at Lake Cecile leased rents.
Current ownership is not charging for trash. Opportunity for immediate revenue by starting a charge back program
Current ownership is not charging for cable or internet.  Opportunity for immediate revenue by starting a charge back program.  There is not a cable/internet contract currently
There is a model unit onsite.  Buyer will have the opportunity to convert that to a rentable unit for immediate revenue
All units have washer/dryer equipment in place.  Opportunity to start charging for washer/dryer equipment.  Typical charge in central Florida is $50 for w/d equipment
The property is owned by a small private group that is typically in the manufacturing houses space.  The property is also self-managed by the owners.  Significant upside with hands-on management to push rents
Opportunity to start charging for water views.
 
 

Rent comps:

Estates at Lake Cecile  3/3 – leased rent $2,329 - 1,508 SF

Estates at Lake Cecile 4/3 – leased rent $2,526 – 1,712 SF

Comps in the area with fully renovated units with similar size units are seeing their 3 bedrooms in the upper $2,800 range – The Lucent at Sunrise and Cacema Townhomes
Comps in the area with fully renovated units with similar size units are seeing their 3 bedrooms in the low $3,000 range – The Lucent at Sunrise and Cacema Townhomes
The Lucent at Sunrise Website Link
Cacema Townhomes Website Link',TRUE,TRUE,''),
('Manor Barrett - Luxury Apartments','6 - Passed','Atlanta, GA',347,2024,325648,113000000,NULL,'2025-04-30','2025-04-30','For Tracking All Docs Saved - Ethan,

Thanks for your note. Guidance on Manor Barrett is ~$113M or $325K/unit (~5.0% cap Year 1). This is a very well executed deal and worth a tour if there’s a potential home for it.

•	Asset Highlights
o	CoStar Impact Award-winning, stabilized new construction product
o	Part podium/part high-density garden construction (40% of the units are podium parked)
o	Elevator serviced, Interior conditioned corridors (10-11’ ceilings on ground/top floor units)

•	Operational Highlights
o	93% occupied
?	New Leases - $2,220 ($2.26P SF) with one-month free
?	Renewal Leases - exhibiting 17% effective rent growth
o	Technology Package (high-speed wifi) - $60/mo charge to residents ($35 net profit to property)
o	Affluent resident demographic – Avg HHI is $142K 

•	Submarket Highlights
o	Kennesaw’s Diversified Employment Base
?	(Meds) - WellStar Kennestone Hospital (2K Employees)
?	(Eds) - Kennesaw State University (45K Students, 16K Employees)
?	Federal Government - Dobbins Air Force Base (6K Employees)
?	Advanced Manufacturing - Yamaha Motor, Textron, Novelis, Airgas-South, Cintas
o	Exceptional single-family housing profile, East Cobb schools, and ring-study demographics
o	Favorable tax environment in Cobb County (~22% lower taxes than surrounding submarkets)
o	Situated in the heart of the 18.1M SF Town Center Commercial District',TRUE,TRUE,''),
('Novus Westshore','6 - Passed','Tampa-St. Petersburg-Clearwater, FL',260,2016,353846,92000000,NULL,'2025-04-28','2025-04-30','For Tracking All Docs Saved - Initial pricing guidance is a $92M, $354k/unit, and a 5.3% T3 tax-adjusted cap rate.  



Located in the heart of Tampa’s largest office market, Novus is a best-in-class, Northwood Ravin-built mid-rise offered significantly below replacement cost and well-positioned for sustained rent growth.



Happy to discuss further and would love to have you in for a property tour!',TRUE,FALSE,''),
('The Griffon Vero Beach','6 - Passed','',297,2024,313131,93000000,NULL,'2025-04-08','2025-04-30','All Docs Saved - Target pricing is $315k per unit.  Stabilized 5.25 cap.  Finishing lease up now.  By far the best deal in this market.  Amazing amenities.  Would you like to arrange a call or tour?  Including Danny for debt menu.',TRUE,TRUE,''),
('Parallel 36 at Jailette','6 - Passed','Atlanta, GA',108,2023,277777,30000000,'2025-05-08','2025-04-08','2025-04-30','All Docs Saved - Ethan,

Guidance is $30M / ~$275K per home, which gets you to about a 5.5% cap.  Nice large floorplans with all three- and four-bedroom floorplans and attached garages for all homes.  Occupancy is 90%+ and strong trend given lack of supply in immediate area and proximity to strong retail and employment. No set CFO at this time but will likely be end of April.
 
Here are some additional highlights:
 
•	Ideal Product in the BFR Space – Purpose-built, fully amenitized, individually parceled homes
o	One- and Two-Car attached garages in 100% of homes
 
•	Strategic Location – Seamless access to key employment drivers in College Park, South Fulton, and greater Atlanta
o	~10 minutes from Hartsfield-Jackson Atlanta International Airport
o	~5 minutes from Camp Creek Marketplace, a 1.2 million-square-foot shopping destination anchored by Publix and Target
 
•	Build-for-Rent Remains Resilient and Attractive – Expectation of continued demand as homeownership remains out of reach
o	$164K average household income onsite paves the way for future rent growth
o	Exceptional lease-up pace with tapering concessions
 
Let me know if you have any questions or would like to set up a tour.

Best,',TRUE,TRUE,''),
('Del Ola','6 - Passed','West Palm Beach-Boca Raton, FL',384,2012,408854,157000000,'2025-05-16','2025-04-15','2025-04-30','All Docs Saved - $157MM',TRUE,TRUE,''),
('Hudson at East','6 - Passed','Orlando, FL',275,2019,252727,69500000,NULL,'2025-04-22','2025-04-30','Tracking PP All Docs Saved -',TRUE,TRUE,''),
('Eight at East Apartments','6 - Passed','Orlando, FL',264,2017,259469,68500000,NULL,'2025-04-22','2025-04-30','Tracking PP All Docs Saved -',TRUE,TRUE,''),
('Winding Oaks Phase II BTR','6 - Passed','Ocala, FL',77,2025,259740,20000000,NULL,'2025-04-29','2025-04-30','All Docs Saved - Hi Ethan,

Thanks for reaching out!

Guidance on Winding Oaks Ph II is $20M ($260K PU / $153 PSF) which equates to a stabilized cap rate of ~6.50%+ after leasing is complete and concessions are burned off. Winding Oaks offers the opportunity to acquire a 77-unit single-family home community to be built by DR Horton on a forward basis in the rapidly growing Ocala, FL MSA with first deliveries set for November 2025.

Deal Room: https://invest.jll.com/listings/living-multi-housing/winding-oaks-ph-ii-ocala-fl

The Property will consist of individually platted, large and efficiently designed 3-, 4-, and 5-bedroom floor plans, all offering 2-car garages, private fenced yards, luxuriously appointed interiors, and concrete block construction. The Property benefits from its location within The Ocala MSA, which ranks as one of the fastest-growing metro area in the United States. Fueled by the continued expansion of industrial & manufacturing hub, the rapid influx of residents has led to increased economic expansion within the area. The affluent community boasts high average household incomes of $117,996 within 1-mile and convenient access to I-75 which provides residents with easy access to major employment hubs in Tampa and Orlando.

Some additional investment highlights include:

Significant discount to retail home values which average ~$430,330 within 5-miles
Record-breaking growth, ranked as the #1 growth for cities located outside top metros
Immediate access to prime retail and medical including The Paddock Mall and Advent Health Ocala
Central location with connectivity to major employers via I-75 and the Florida Turnpike
Let me know if you want to hop on a call to discuss.',FALSE,TRUE,''),
('MAA Mass Avenue','6 - Passed','Washington, DC-MD-VA',269,2002,631970,170000000,NULL,'2025-04-22','2025-04-30','All Docs Saved - 
Ethan,

Thanks for reaching out. We are guiding to $170mm+ which is about $625k/unit and just over a 5% cap on T-3/T-12 actual. Bigger units - 882 Avg with 62% 1BR+Den or larger. Trade outs have been 8% YTD and renewals have been 5.3%. 100% of the units are market rate and ready for a value add with meaningful headroom compared to neighboring class A comps. Let me know if you would like to jump on a call and/or meet for a tour.',TRUE,TRUE,''),
('101 Via Mizner Luxury Apartments','6 - Passed','West Palm Beach-Boca Raton, FL',366,2016,751366,275000000,NULL,'2025-04-21','2025-04-30','Tracking PP Bankruptcy Sale

All Docs Saved - Ethan – 

Whisper pricing is $275M for the property which is approximately $250M for the apartments and $25M for the retail portion. Let me know if you would like to discuss. 

Thank you,',TRUE,TRUE,''),
('The Slate','6 - Passed','Savannah, GA',272,2018,246323,67000000,'2025-05-06','2025-03-31','2025-04-30','All Docs Saved - Ethan,

Appreciate your interest.

Pricing is $67M (~$245k/unit), which is a trending 5.50% in-place cap rate based on current rent roll and will be a 6.0% cap rate year one through increasing rents to recent trade outs ($1,850).

Property performance remains strong as recent trade-outs average 9% while retaining 95%+ occupancy, allowing for immediate upside day one.
 
Savannah continues to see generational growth with 8,500 new jobs by Hyundai EV which is expected to lead to total of ~40,000 total new jobs in the metro (20% of current work force). Also, Georgia Tech completed a housing needs assessment report showing Savannah MSA needs 41,000 by 2030 due to Hyundai growth.

The OM will be available next week. CFO is likely in early May.
 
Let us know when you are available to discuss and/or tour.',TRUE,TRUE,''),
('Rosser Avenue BTR','6 - Passed','',90,2025,277777,25000000,NULL,'2025-04-21','2025-04-30','All Docs Saved - Thanks for reaching out and hope all is well. We are targeting $275k per unit for the Rosser Avenue which would be a 6.0% stabilized cap rate.  The owner here is DR Horton.  Construction for Rosser is starting in July 2025, first CO expected in October 2025, and final CO expected in August 2026.  They are looking for a forward take out and would be comfortable with a staged take down as townhouse units deliver (likely in smaller packages of 5 to 10 units).  DR Horton did this in the sale of their West Virginia asset a couple of years ago.
 
Please feel free to reach out if you have any additional questions and let us know if you would like to discuss further.',FALSE,TRUE,''),
('Sophia Bethesda','6 - Passed','Washington, DC-MD-VA',276,2025,670289,185000000,NULL,'2025-04-08','2025-04-30','All Docs Saved No T12 - Hi Ethan,

Guidance is below. Let us know if you’d like to set up a tour. Thank you

$185MM - $190MM
•	Residential - $180MM - $185MM ($650K/Unit)
•	Retail - $5MM
•	~5.50% Year 1 Cap Rate (Unabated)
•	Low-5.00% Year 1 Cap Rate Tax Adjusted (Unabated)
•	Additional ~25bps on Abated Cap Rate',TRUE,TRUE,''),
('Legacy on Rockhill BTR','6 - Passed','',128,2024,275000,35200000,'2025-05-01','2025-04-01','2025-04-30','All Docs Saved, No OM - We are guiding at $275K per unit, reflecting a mid-5% cap rate on stabilized numbers. This asset was developed by a Phoenix-based developer and built by a division of Highland Homes (HHS), featuring some of the nicest finishes and amenities in the submarket.
 
This prime location has experienced rapid growth, with over 10 million SF of office space under construction or planned in McKinney and Allen. The property is also just minutes from Downtown McKinney, home to the area''s best shops, restaurants, and nightlife.
 
Let us know if you’d like to schedule a tour or if there’s anything else we can assist with.',TRUE,TRUE,''),
('Ashton at Dulles Corner','6 - Passed','Washington, DC-MD-VA',454,2008,330396,150000000,'2025-05-01','2025-04-01','2025-04-30','Tracking PP
All Docs Saved - Hi Ethan, 
Please see below high level guidance and overview. Let me know if you want to connect in more detail.

 

150M - $330k/unit and $326/sf…big units
Low 5 cap rate
Lease trade-outs (last 60 days/50+ leases)
New leases – 9.7%
Renewals – 9.4%
Renovations
81% original or minor changes
19% renovated with quartz countertops, new LVT flooring…~$200 rent premium',TRUE,TRUE,''),
('Estero Oaks','6 - Passed','Fort Myers-Cape Coral, FL',280,2017,294642,82500000,'2025-05-01','2025-04-01','2025-04-30','All Docs Saved - Guidance for Estero Oaks is $82.5MM. CFO is set for May 1st.',TRUE,TRUE,''),
('Keys at Cotee River','6 - Passed','Tampa-St. Petersburg-Clearwater, FL',126,2024,280000,35280000,'2025-04-30','2025-03-31','2025-04-30','All Docs Saved - Guidance is set at $280K per unit, which equates to a 5.75% year-one stabilized cap rate (tax-adjusted at 80% sale recapture).

Please note: our cap rate reflects a 3% increase in top-line rents and includes two additional revenue streams—washer/dryer rentals and a screened-in porch upgrade.

Let me know if you''d like to jump on a call to discuss further.',TRUE,TRUE,''),
('Ascend Oakpointe Apartments','6 - Passed','Orlando, FL',240,2023,262500,63000000,'2025-04-30','2025-03-28','2025-04-30','All Docs Saved - Ask on Ascend Oakpointe is $63M, low $260K''s per door which is a low 5% on their in-place rent roll, including some leasing concessions, with stabilized operations and post-sale taxes. Looking at where recent leases have been signed and still keeping a small concession, the cap rate improves to a 5.4% Yr. 1 tax-adjusted cap rate.

This is a brand-new, 3-story garden asset developed by D.R. Horton located in the Apopka submarket, with direct frontage along the SR 429 Western Beltway and less than 5 minutes from the AdventHealth Apopka medical campus. Apopka has been one of Orlando''s largest growth corridors the last few years and has evolved into a dynamic rental market, which is reflected by Ascend Oakpointe being one of 6 new projects to deliver since 2023. Today, almost all of these projects are now stabilized and there are only 2 other projects that are under construction within a 5-mile radius. This should give new ownership a fantastic opportunity moving forward to push rents upwards on new leases and renewals due to the limited future supply.

The Property has superior connectivity relative to the comps as it is located directly at the interchange of SR 429 and Ocoee-Apopka Rd, providing easy accessibility onto the SR 429 Western Beltway. This allows residents convenient access to multiple healthcare facilities including AdventHealth Apopka (158 beds), AdventHealth''s office headquarters in Maitland (2K+ employees), Orlando Health Health Central (252 beds), and AdventHealth Winter Garden (100+ beds), as well as major white-collar employment nodes including the Maitland and Winter Park office markets, Downtown Orlando, and Horizon West which are all less than 25 minutes from the Property.

Please let us know if you have any questions as you review or if you would like to schedule a tour of the property.',TRUE,TRUE,''),
('The Palms at Edgewater','6 - Passed','Charleston-North Charleston, SC',288,2023,230000,66240000,'2024-10-09','2024-09-05','2025-04-30','All Docs Saved - Guidance on Palms is mid $230/unit which around a 5.25% cap year one.

Pre-leased at 88% with new leases signing at $1,663 and the first round of renewals coming due (latest renewals signing at $1,708), there is a great opportunity to push rents on second gen leases and bridge the gap to top of market comparables: The Ames ($1,807), The Murray ($1,830), and Slate Nexton ($1,799), providing a compelling narrative of significant organic rent growth and mark-to-market potential.

 

See below a few deal points for the property. Our OM should be out Wednesday of next week and CFO will be October 11th.

 

Property Website: https://thepalmsatedgewater.com/
Eff. Rent: $1,624 / Avg. Unit Size: 1,004 SF / Occupancy: 84% (88% Preleased)
Impressive Lease-up Momentum:
27 avg. monthly move-ins since Jan 2024; 48 move-ins in July
Now 88% leased while only offering one month of concessions
Mark-to-Market Potential: New ownership has the opportunity to push rents organically and bridge the $150 avg. rent deficit
The Ames (2024 Lease-Up): $1,807
The Murray (2021 Build): $1,830
Slate Nexton (2022 Build): $1,799
Elevate at Brighton Park (2019 Build): $1,783
State-of-the-Art Asset:
Resort-Style Saltwater Pool w/ Sundeck, Scenic Lake with Uplit Fountains, 2 Pickleball Courts, 24-hr fitness studio, Billiard/Game Lounge, Parcel Lockers, 2 Pet Parks, Pet Wash Station, Detached Garages available
9 Foot Ceilings, Granite Counters, Keyless Entry, Custom White Cabinetry, Scenic Views Available, Walk-In Closets, Private Patio w/ Storage available, Kitchen Pantry, in Home W/D Connections
3M+ SF of Premier Retail: 15 minutes from 3.4M SF of retail including Target, Walmart, Lowes, TJ Maxx, Best Buy, and popular dining such as Chick-Fil-A, Chipotle, Crumbl Cookies, and Starbucks within the densely populated retail and grocery corridor along South Main Street.
Access to Top Employers: 25 mins to 50k+ jobs, including Robert Bosch (2k+ employees), IQor (1.2k+ employees), Trident Medical (2.6k+ employees), MUSC Health (16k+ employees), Mercedes-Benz (1.6k), Charleston International Airport (3k+ employees), Joint Base Charleston (22k employees)
Connectivity to Major Markets: 45 minutes from Charleston, 1.5 hours from Columbia, and less than 2 hours from Savannah
Recent Summerville & Ridgeville Economic Investments:
Redwood Materials: $3.5B, 1,500 New Jobs
Sagebrook Homes: $80M, 117 New Jobs
KION North America: $40M, 450 new jobs
Honor LSC: $34.2M, 65 new jobs
Sportsmans Boat Manufacturer: $8M, 75 new jobs',TRUE,TRUE,''),
('Cortland Sugarloaf','6 - Passed','Atlanta, GA',406,2001,229064,93000000,'2025-04-24','2025-04-02','2025-04-29','All Docs Saved - Ethan,

Price guidance is mid-$90M or $230sk/unit, which is a low-5% in-place cap rate. Let us know if you would like to schedule a tour.
 
•	High-quality product: 9’ ceilings, spacious floor plans w/ granite countertops
•	Zoned for “A” rated Peachtree Ridge High School
•	Adjacent to Northside Hospital Gwinnett’s Major $400M expansion
•	Three miles from Georgia Gwinnett College (12,000+ enrollment)
•	Surrounded by thriving distribution and logistics jobs
•	Offered 20% below replacement cost of new comps nearby
•	Value-add upside: finish install of W/D and stainless appliances, plus new cabinet fronts and light fixtures',TRUE,TRUE,''),
('Sorrento','6 - Passed','Phoenix-Mesa, AZ',226,1983,199115,45000000,'2025-04-24','2025-03-25','2025-04-24','All Docs Saved -
-	Sorrento:
o	Long term owner (2016), business partner passed away
o	Had offers at 315 at peak, mid-low 40M range (180/190/unit)
o	Timing – CFO in ~month
o	B deal, B location
o	Full value-add
o	Current owner did ext paint
-	Just signed listing on 150 units in Mesa for brand new deal coming soon


 Jay,

Thanks for reaching out on Sorrento and we think pricing will be in the mid $40m range.  It was institutionally owned by Fairfield and then Hamilton Zanze, but has been privately owned for the last 10 years.  Strong pride of ownership with no deferred maintenance and average occupancy exceeding 95% over the last 5 years. 
 
Hamilton Zanze added a washer and dryer in one unit to prove out the install back in 2014.  Current owner did not have the bandwidth to undergo a major renovation project so 100% of the units can be upgraded. Really good pocket of Mesa and below are the deal points.

•	100% of the units can be upgraded including adding washer/dryers(one unit has w/d installed)
•	Strong infill East Valley location that is not pressured by the development pipeline
•	On the boarder of East Tempe, South Scottsdale and North Chandler which has some the of highest rents in the entire market.
•	Amazing access to the entire valley, located one mile from the Loop-101 and US-60 freeways
•	Right next to Banner Desert Medical Center (ranked as one of the top 5 hospitals in the Phoenix MSA) and Mesa Community College (17,400+ students)
•	Located in one of the densest job corridors with 1M+ jobs in the immediate commute shed
•	Agency Financing Eligible (99.1% Mission Driven); sub 100bp spreads are available. Contact our financing team for loan options.',TRUE,FALSE,''),
('The Jade at Avondale','6 - Passed','Atlanta, GA',270,2020,262962,71000000,'2025-04-29','2025-03-25','2025-04-24','All Docs Saved - Ethan,

 

Appreciate you reaching out on this one.

 

Total pricing is $71M ($263K/Unit) which includes 7K SF of retail and 5 years of abated taxes totaling $4M+ in savings. 

Multifamily pricing is $67.3M ($249K/Unit) which is a 5.12% T1 cap rate with unabated taxes and a 6.29% Year 1 cap rate with abated taxes.

 

The Jade was developed by TCR with thoughtful finishes and quality construction and is within the Avondale Estates open container district, which is walkable to 300K+ SF of desirable restaurants and breweries.

 

Supply/demand dynamics in the Decatur submarket are the best in infill Atlanta, with no competing properties in lease-up and only one property under construction.

 

Also, the property is signing recent leases +2.5% over current in-place rents.',TRUE,TRUE,''),
('Berkshire Place Apartments','6 - Passed','Charlotte-Gastonia-Rock Hill, NC-SC',240,1982,165000,39600000,NULL,'2025-03-10','2025-04-24','All Docs Saved - 165k/unit

update 3/18: uw done, waiting on OM for value-add',TRUE,TRUE,''),
('33 West Apartments','6 - Passed','Fort Lauderdale-Hollywood, FL',376,2014,337765,127000000,NULL,'2025-04-21','2025-04-24','Tracking PP - 
All Docs Saved - Ethan…Target is $340k per unit. Thanks.',TRUE,TRUE,''),
('Sterling Town Center','6 - Passed','Raleigh-Durham-Chapel Hill, NC',339,2013,218289,74000000,'2025-04-10','2025-03-10','2025-04-21','All Docs Saved - $74MM',TRUE,TRUE,''),
('Carrington at Perimeter Park Apartments','6 - Passed','Raleigh-Durham-Chapel Hill, NC',266,2008,240601,64000000,'2025-04-16','2025-03-18','2025-04-21','All Docs Saved - $64M',TRUE,TRUE,''),
('Level at Sixteenth Apartments','6 - Passed','Phoenix-Mesa, AZ',240,2010,260000,62400000,NULL,'2025-04-01','2025-04-21','All Docs Saved, No OM - ±$260k per unit',TRUE,TRUE,''),
('Be Mesa','6 - Passed','Phoenix-Mesa, AZ',244,1987,237704,58000000,'2025-04-23','2025-03-26','2025-04-21','All Docs Saved - Hi Jay, 

Guidance is $58M.',TRUE,TRUE,''),
('Graces Reserve Apartments','6 - Passed','Charlotte-Gastonia-Rock Hill, NC-SC',240,2021,225000,54000000,'2025-04-23','2025-03-17','2025-04-21','All Docs Saved - Guidance is $235k/door / $54mm which is a 5.5% in place without the tax abatement and 6.5% in place with the tax abatement. Ownership recently partnered with the non-profit Foothills Affordable Housing Foundation to achieve the tax abatement providing fully abated taxes in 2025 (detailed on page 10 of the OM). New ownership can partner with Foothills as well to keep the abatement in place going forward on a year by year basis. Below are the in-place rents along with the required rent limits to qualify for the tax abatement.',TRUE,TRUE,''),
('Walden Lake Apartments','6 - Passed','Tampa-St. Petersburg-Clearwater, FL',352,1994,167613,59000000,'2025-04-23','2025-03-20','2025-04-21','All Docs Saved - Around $59M. $160,000s/ unit',TRUE,TRUE,''),
('Compton Place Apartments','6 - Passed','Tampa-St. Petersburg-Clearwater, FL',384,1998,214843,82500000,'2025-04-22','2025-03-31','2025-04-21','All Docs Saved - Ethan,
 
Thanks for your interest in Compton Place, a late 1990’s vintage community that we are selling for the first time since its inception for the original developer. The property boasts some of the largest floor plans in the submarket at an average of 1,250 SF with 9’ or higher ceilings throughout as well as full-size washer/dryers, screened-in patios/balconies and open kitchen concept layouts.
 
The property is located in the heart of the prestigious Tampa Palms submarket with strong demographics such as $145k median household income in a 1-mile radius,  all “A” and “B” zoned schools and significant retail and employment in the proximity with 343,000 jobs accessible within a 45-minute commute. The property has frontage to Bruce B. Downs Blvd (over 51k daily car count) and is minutes away from Interstate-75 allowing ease of commute throughout Tampa Bay.
 
With classic finish levels in all units, there is a generational opportunity to renovate 100% of the units to luxury grade standards to achieve a $250+ premium on rent as well as capitalizing on an attractive site layout surrounded by a nature preserve and 7,000 SF clubhouse, primed for new and revamped amenities.
We are expecting to trade this asset between $82.5 million ($215k/unit) to $84.5 million ($220k/unit) which is a projected fully renovated 6.2% to 6.4% CAP rate (inclusive of updated tax, insurance and cap ex in the basis). The property is being offered free and clear of debt. 
 
If you would like to discuss the opportunity further or schedule a tour, please contact the lead agents Mike Donaldson at (727) 946-7611 or mike.donaldson@cushwake.com and Nick Meoli at (813) 462-4222 or nick.meoli@cushwake.com.
 
For financing and other capital stack options, please contact Errol Blumer with our equity/debt/structured finance team at (727) 641-8799 or Errol.blumer@cushwake.com.
 
A bid deadline has been established for Tuesday, April 22, 2025.',TRUE,TRUE,''),
('Parkside Punta Gorda','6 - Passed','Punta Gorda, FL',297,2023,242424,72000000,'2025-05-08','2025-01-07','2025-04-21','All Docs Saved - 
$72MM now with JBM

Guiding to 250k/unit 
Year 1 5.7% cap
Fully leased up (17-18 units month)
No new supply
Broker acted like pricing might go even lower that that, have not gotten much feedback on the deal. Guiding to 250/unit for now',TRUE,TRUE,''),
('Lofts at Eden','6 - Passed','Orlando, FL',175,2017,228571,40000000,NULL,'2025-03-31','2025-04-21','All Docs Saved  - Around $40 million - like $228k per unit',TRUE,TRUE,''),
('Evolve Homestead Apartments','6 - Passed','Greenville-Spartanburg-Anderson, SC',240,2023,237500,57000000,NULL,'2025-04-04','2025-04-21','All Docs Saved - Hi Ethan,

 

Apologies for not answering earlier; it’s been a very busy week with activity on this deal. We’re targeting $57MM ($237,500 / unit), which is a 5.1% cap on in-place operations. Management has been incentivized on occupancy through lease-up and stabilization (understandably), and as a result, the operations have a loss-to-lease that really adds the juice to this asset. We see a $250 / unit / month LTL to meet market average rents, and a ±$350 / unit / month LTL to reach what we feel are the achievable rents on the property.

 

We are arranging tours on April 23rd, with a Call for Offers on April 30th. If you are not available on the tour date, we can make other arrangements to accommodate your schedule.

 

Please let me know if you have any other questions. I’m available at your convenience.',TRUE,TRUE,''),
('Willows at Grande Dunes','6 - Passed','Myrtle Beach, SC',321,2023,218068,70000000,'2025-04-23','2025-03-25','2025-04-21','All Docs Saved - Morning Ethan,
We are guiding to $220’s a door, yielding a mid-teen return and neutral+ leverage day one.
Let us know if we can help provide anything else,
Charlie',TRUE,TRUE,''),
('Queen City BTR','6 - Passed','Charlotte-Gastonia-Rock Hill, NC-SC',102,2025,392156,40000000,'2025-04-23','2025-03-31','2025-04-21','All Docs Saved - 3 pack total of 102 units forward sale 

Guidance is just under $40M, pricing to a proforma 6% cap rate. Very rare group of Horton deals given how infill these are.

OM should be out next week.',FALSE,TRUE,''),
('1016 Lofts','6 - Passed','Atlanta, GA',265,2003,226415,60000000,'2025-04-22','2025-04-02','2025-04-21','All Docs Saved - Ethan,

Thanks for your note. Guidance on 1016 Lofts is $60M or $226K/unit, inclusive of the retail. The cap rate at guidance reflects a post-renovation, stabilized yield north of 6%. The asset is comprised of mostly classic finishes (2003 vintage) and offers a new buyer immediate renovation upside upon acquisition.
 
•	Strategic Renovation Opportunity - Ability to renovate unit interiors (stainless steel appliances, microwaves, lighting/plumbing fixtures, granite countertops, new cabinet fronts, bathroom upgrades, etc.) and close the $400-500 rent spread to new construction comparables in West Midtown.
o	Property is in excellent physical condition allowing new owner to focus value add capital on revenue enhancing improvements
 
•	West Midtown: Atlanta’s Most Dynamic Submarket – Rare opportunity to acquire an asset with vintage and material upside in a thriving and walkable mixed-use environment across from two of Atlanta’s most exciting office complexes (Star Metals & Interlock).
o	1016 Lofts has ~6K SF of ground floor retail 
   
•	Discount to Replacement Cost with Irreplicable Construction Type – 50%+ discount to replacement cost. Unique 6-story concrete construction is irreplicable in today’s development environment given cost/required density to capitalize.
 
We’d be happy to discuss in more detail at your convenience.',TRUE,TRUE,''),
('Landon Green Artisan Cottages BTR','6 - Passed','Hickory-Morganton-Lenoir, NC',100,2023,340000,34000000,NULL,'2025-03-25','2025-04-21','More for Tracking - 
All Docs Saved - Pricing: $34M ($340k/door), which equates to a 5.4% cap rate.
Download the OM, RR, T12, Renewal Tracker, etc. here: https://clientportal.berkadia.com/opportunities/006Pf00000Oeo5BIAR

Timing: All offers are due by 5 p.m. ET on April 23. Offers will be reviewed as they are received.

Property Tours: Will be provided on a first come, first serve basis. Please reach out to our team to schedule and allow at least 48-hours advanced notice.

Financing: Indicative debt quotes for both agency and non-agency options are in our Doc Center and were completed by Joel Kirstein on Berkadia’s BTR/SFR mortgage banking team.

Highlights and Notes:
-	Unit mix is 2 and 3 bedroom front-loaded 2-story townhomes
-	The property is just now seeing lease renewals and 2nd generation leases – the asset has had a 67% retention rate YTD and is experiencing ~4% organic rent growth.
-	The property has a full amenity set: clubhouse, gym, pool, and dog park
-	My Niche Apartments has handled lease up and is the 3rd party property manager
-	The asset is single-platted and is fully assessed.
-	Please see OM and FAQ file in Doc Center for other details regarding the Seller/GC, staffing, taxes, etc.',TRUE,TRUE,''),
('Skyline Farmers Market','6 - Passed','Dallas-Fort Worth, TX',340,2016,170588,58000000,'2025-04-30','2025-03-25','2025-04-21','All Docs Saved - Hi Ethan,

 

Pricing guidance is low to mid $170k/unit. We sold it for a fair amount more than that in summer of 2022. Originally developed by Alliance and is in great shape. Rents are cheap because they had to switch management companies and now the deal is performing. The last four or five months are what you should focus because of the management change and those trailing cap rates are trending up and in the upper 4s on the most recent numbers. Happy to discuss over the phone in more detail.',TRUE,TRUE,''),
('Bluffs at Midway Hollow','6 - Passed','Dallas-Fort Worth, TX',473,2019,230443,109000000,NULL,'2025-04-09','2025-04-21','All Docs Saved - Ethan – thanks for reaching out. Pricing guidance here is ~$230k/u (+/-$109mm), which equates to an upper-4% in-place cap rate (T3/T12 – adjusted for stabilized taxes and insurance, as well as to current A/R report and no concessions given current Property operations).',TRUE,TRUE,''),
('Visions at Willow Pond','6 - Passed','West Palm Beach-Boca Raton, FL',300,1987,256666,77000000,'2025-04-17','2025-03-18','2025-04-21','All Docs Saved - 

JS: looks interesting, but 4.7 cap...

Pricing is 77 million. There are 53% of the units that are renovated achieving an average of $175 premium. Let me know if you have any questions and if you would like to schedule a tour.',TRUE,TRUE,''),
('Marden Ridge Apartments','6 - Passed','Orlando, FL',272,2017,242647,66000000,'2025-04-16','2025-03-24','2025-04-16','All Docs Saved - Offered in a portfolio, IPA was selling in early 24, refi. Guidance was $65MM back then

$66MM Now, 4.5% Cap in place',TRUE,TRUE,''),
('Triton Glen','6 - Passed','Richmond-Petersburg, VA',250,2024,270000,67500000,'2025-04-15','2025-03-03','2025-04-11','All Docs Saved - Apologies for the delay here and appreciate you all digging in, it’s not common for a property of this caliber to hit the market in this part of Richmond.  Brief rundown below on the opportunity but would be better to jump on a call to chat through. Also including some language on its sister community, we are marketing, Triton Scott’s Addition, as they can be purchased together or separately. 
 
Guidance: $67.5M ($270/door) which is an 5.54% cap rate on a stabilized basis (over a 6% cap on owner’s budget). 
 
Doc Center: https://clientportal.berkadia.com/opportunities/006Pf00000ODNE0IAP
 
•	250 units 2024 construction
o	First resident move-ins were December 2023 but didn’t receive our final CO until November 2024
o	We are seeing our first renewals and averaging a 67% retention rate
•	Currently Occupied at 83% and leased at 88%
•	Residents have given extremely positive feedback on the unique features of the product, which include two of the largest courtyards in the market, only property in the submarket with units with individual fenced-in yards, and larger-sized units compared to neighboring properties.
•	There is a lack of incoming new supply of luxury apartments. Under 700 units coming to the market within the next 2 years
•	Located with the Innsbrook Business Park – One of the state’s largest employment centers (630 acres) that is home to over 8 Million sf of office, that supports 500 companies and 20,000 employees driving $3.1 Billion in annual economic impact 
o	This micro location is exceptional, strategically located at the back of the Innsbrook Office Park and adjacent to the I-295 intersection. Additionally, we are directly off Nuckols road, which takes you directly to one of the most affluent neighborhoods in the West End of Richmond, Wyndham.
•	Strategically located within the coveted Henrico County Public School District that is consistently ranked among the most sought-after school district in the country',TRUE,TRUE,''),
('Triton Scott''s Addition','6 - Passed','Richmond-Petersburg, VA',263,2025,304182,80000000,'2025-04-09','2025-02-07','2025-04-11','All Docs Saved - Ethan – 

Apologies for the delay here. We’re guiding to the low $80M mark for Triton Scotts (which should actually be called Triton Monument as you can literally walk out your front door onto Monument Ave – giant perk). As you’ll see, we’re just now starting pre-leasing, but are currently 0% leased and priced as such. Our basis of ~$305k/unit feels like a development basis (actually less then development basis as we’re raising equity for another site in Scotts that is closer to the $350k/unit range), although you’re buying existing product. May be easier to jump on a call to chat through this as it’s a little more nuanced. Let us know when works and we’ll try to be flexible.

Best,
Carter',FALSE,TRUE,''),
('Creekside BTR','6 - Passed','Fort Pierce-Port St. Lucie, FL',119,2025,279831,33300000,'2025-04-10','2025-03-13','2025-04-11','All Docs Saved - Ethan,

Thanks for reaching out!

Guidance on Creekside is $280-$290K PU ($191-198 PSF) which equates to a stabilized cap rate of ~6.50% after leasing is complete and concessions are burned off. Creekside offers the opportunity to acquire a 119-unit townhome community to be built by DR Horton on a forward basis in the rapidly growing Port St. Lucie, FL MSA with first deliveries set for November 2025.

Deal Room: https://invest.jll.com/us/en/listings/living-multi-housing/creekside-fort-pierce-fl-

The Property will consist of single-plat, large and efficiently designed 3-bedroom floorplans (1,464 SF on average), all offering 1-car garages, 2-car driveways, private entry back patio, luxuriously appointed interiors, and concrete block construction. Further differentiating the Property is its impressive access to community amenities, which are a part of a larger CDD. These amenities offer residents a range of conveniences including a large park, an expansive clubhouse, resort-style pool and more. Note that the Property is subject to a CDD O&M fee of $500/unit for ongoing maintenance and upkeep of the shared amenity space. Creekside also benefits from its location within the Port St. Lucie MSA, with 20% projected population growth and high average household incomes of $120,449 (within 1-mile). The Property also has convenient entry to I-75 and the Florida Turnpike which provides residents with easy access to major employment hubs in Miami, Jacksonville, and Orlando.

Some additional investment highlights include:

Significant discount to retail home values which average ~$498k within 5-miles
Record-breaking population growth, with 20%+ 5-year population growth projected within 1-mile
Immediate access to prime retail and medical including The Landing at Tradition and HCA Florida Lawnwood Hospital
Central location with connectivity to major employers via I-75 and the Florida Turnpike
Let me know if you want to hop on a call to discuss.

Thanks,',FALSE,TRUE,''),
('Indigo Springs','6 - Passed','Phoenix-Mesa, AZ',240,2000,245833,59000000,'2025-04-10','2025-03-17','2025-04-11','All Docs Saved - ±$59M',TRUE,TRUE,''),
('The Tiffany at Maitland West','6 - Passed','Orlando, FL',315,2018,253968,80000000,NULL,'2025-03-25','2025-04-03','All Docs Saved - $80MM Low 4 cap in place',TRUE,TRUE,''),
('Brickstone Maitland Summit','6 - Passed','Orlando, FL',272,1998,264705,72000000,NULL,'2025-03-21','2025-04-03','All Docs Saved - 72MM

4.5 cap yr 1, big tax reassessment',TRUE,TRUE,''),
('Bungalows at San Tan Village','6 - Passed','Phoenix-Mesa, AZ',159,2024,389937,62000000,'2025-03-27','2025-02-14','2025-04-02','3/18: offer next week, pros and cons to this deal, did not love arch

All Docs Saved - Ethan -  thank you for your message today.

First the reason for this upcoming market effort:  Cavan Companies is a merchant builder and Bungalows at San Tan Village will be the 7th such community for this developer I will have taken to market.  Cavan typically sells following completion of construction and successful completion of the lease up.  Please note that this is not a distressed sale – rather is an attractive long-term opportunity on one the premiere assets  to come to market in the East Valley of Metro Phoenix.

We plan on formally launching Bungalows at San Tan Village in Gilbert later this month with a targeted COE tied to the June payoff of the existing loan – property is currently 93% leased and 85% occupied.   However, at the request of several investors, we are already conducting tours.

Given the overall strength of the Gilbert submarket, quality of asset, etc., we are whispering $390,000+ per unit for this opportunity - 5 CAP going in and increasing to 5.5 +/- we suggest likely in year 1.  

Bungalows at San Tan Village – offering full amenities and unmatched floor plans - is one of the highest quality communities we have ever listed.

If you are working today, please call at 602.526.4800 should you wish to discuss other; or call tomorrow when free.

Thank you for your preliminary interest in what I deem an unusually attractive offering.',TRUE,TRUE,''),
('Cortland Colburn','6 - Passed','Orlando, FL',300,2024,395000,118500000,'2024-12-10','2024-11-20','2025-04-02','All Docs Saved - Jay – guidance is $395K per unit, inclusive of the retail (<5% of NOI).

5.25% cap rate using in-place effective rents & retail income
5.50% cap rate using recent effective rents & retail income
 

Key deal points below –

Barriers – no more multifamily entitlements remain in Celebration
Product – Streetlights only development in FL
10’ or higher ceilings in every unit
For-sale quality interiors, providing true alternative to home ownership
On-Site Demographics - $180K Avg. HH Income, $140K Median
Operations – stabilized & trending
95% occ., 97% leased
$2,700+ recent effective rents (across unit mix)
9%+ blended LTO
Top MSA growth projections
#2 in job & population growth nationally through 2029
#8 in rent growth nationally through 2029
 

Let us know if you’d like to talk through further or if you’ll be in town to tour in the next couple weeks.',TRUE,TRUE,''),
('Layers Galleria','6 - Passed','Dallas-Fort Worth, TX',330,2013,181818,60000000,NULL,'2025-03-25','2025-03-27','All Docs Saved - Hey Ethan, 

We anticipate Layers Galleria to trade in the $60M to $61M ($182-$185K per unit) range which is significantly below replacement cost. Built in 2013, the property is located in Farmers Branch, just off the Dallas North Tollway and I-635, adjacent to the Galleria Mall along the Platinum Corridor.
 
The property offers a unique mix of garages, townhomes, and both structured and surface parking, setting it apart from its competition. Located in the heart of North Dallas'' economic and entertainment district, and benefits from proximity to major employers such as Atmos Energy, Ryan, Amazon Web Services, Wells Fargo, Merrill Lynch, and Expedia Group, with over 9.9M SF of office space and 350,000+ jobs within a ten-mile radius.
 
New ownership has the potential to enhance operations by renovating 70 classic units to a renovated scope that include upgraded lighting, smart home features, backsplash, and vinyl wood flooring.  
 
A Call For Offers date has not been set yet but will likely be late April.
 
Please let us know if you have any questions or would like to schedule a property tour.',TRUE,TRUE,''),
('Banyan Bay Apartment Homes','6 - Passed','Fort Lauderdale-Hollywood, FL',416,1986,235576,98000000,NULL,'2025-03-25','2025-03-27','All Docs Saved - Ethan…target on this is $235k per unit. Thanks.',TRUE,TRUE,''),
('Axis 3700','6 - Passed','Dallas-Fort Worth, TX',300,2016,236666,71000000,'2025-04-11','2025-03-25','2025-03-26','All Docs Saved - $71MM',TRUE,TRUE,''),
('Verlaine on the Parkway','6 - Passed','Dallas-Fort Worth, TX',294,1994,163265,48000000,NULL,'2025-03-17','2025-03-26','All Docs Saved - Hey Ethan, 

We expect Verlaine on the Parkway to trade in the $165K-$170K/unit range, putting you around $48M-$50M all-in. Located in the economic and entertainment core of North Dallas, the property is situated on 11 acres fronting the Dallas North Tollway and benefits from more than 350,000 jobs within a ten-mile radius. Verlaine is walkable, and sits right next door, to Village on the Parkway which features multiple high-end retail and entertainment options and anchored by Whole Foods.

50% of units remain in classic condition and can be taken to the fully renovated scope which includes quartz countertops with farmhouse sink, backslash, stainless steel appliances, cabinet paints & hardware, lighting & fixtures. Additionally, new ownership can add smart homes to all units, 20 pet yards, and 282 washer/dryer sets. 
 
Lastly, the asset is offered free and clear of existing debt and CFO is expected to take place in early April.

Let us know if you have any other questions or would like to schedule a tour.',TRUE,TRUE,''),
('WestEnd25 Apartments','6 - Passed','Washington, DC-MD-VA',283,2009,653710,185000000,NULL,'2025-03-19','2025-03-25','Tracking Purposes 

All Docs Saved - 

Whisper price is $185M which is a T3/T12 Real estate tax adjusted 5% cap. There is about 35 bps of expense saving as JBGS expense are very heavy. We solved to a 6.5% YR3 ROC, there are significant proven premiums $415 average on standard units and $1000+ on the units overlooking Rock Creek Park / Penthouse units. Let me know if you all would like to schedule a tour and our talk through the deal.',TRUE,TRUE,''),
('1100 Apex Clearwater Apartments','6 - Passed','Tampa-St. Petersburg-Clearwater, FL',134,2019,253731,34000000,NULL,'2025-03-05','2025-03-25','All Docs Saved - Ethan,
 
Thanks for your interest in 1100 Apex, a rare 15-story 134-unit tower in downtown Clearwater in the Tampa Bay MSA with additional ~3,500 SF of ground floor retail. The property is situated in downtown Clearwater which has over 8,000 employees in the vicinity and is within biking distance from world renowned Clearwater Beach. The property was originally an office building that was completely gutted and transformed in 2019 to the premier residential community in Clearwater that is today. The property features best-in-class amenities for the area with a golf simulator, heated resort style swimming pool, a private dining area and kitchen prep room and even an outdoor pool table, to name a few. Furthermore, the units are some of the largest in the competitive set with open concept floor plans, high-end finishes throughout and smart technology such as keyless entry and smart lighting.
 
There is an affluent tenant base at the property with residents that currently have income 4.6x the rent and only a 21% rent-to-income ratio which provides support for additional rent increases. The property is also poised to benefit from being in the most populated county in Florida with high barriers to entry and only 860 units currently under construction nearby and Costar projecting 15% rent growth over the next five years.
 
We are expecting to trade this asset around $34-35 million which is $257k/unit and $231/SF (inclusive of the retail space), a going-in tax and insurance adjusted 5.3-5.4% CAP and a projected end of year one 6.5-6.7% CAP rate with no rent growth modeled for the first year. The property is being offered free and clear and have sized up debt options through our Greystone partners.
 
If you would like to discuss the opportunity further or schedule a tour, please contact the lead agents Mike Donaldson at (727) 946-7611 or mike.donaldson@cushwake.com and Nick Meoli at (813) 462-4222 or nick.meoli@cushwake.com
 
For financing options, please contact Donny Rosenberg with our Greystone finance team at (646) 265-2414 or Donny.Rosenberg@greyco.com.',TRUE,TRUE,''),
('Element at the Grove','6 - Passed','Raleigh-Durham-Chapel Hill, NC',312,2024,240384,75000000,'2025-04-02','2025-02-13','2025-03-25','All Docs Saved - – guiding 240k per door here which is y1 5 cap. Chat next week',TRUE,TRUE,''),
('Park at Palm Valley','6 - Passed','Phoenix-Mesa, AZ',300,1982,200000,60000000,NULL,'2025-03-06','2025-03-25','All Docs Saved - Hi Ethan,
We’re looking for $60M ($200K per door).  In Place 5.5 cap.  Built in 2 phases in 82 and 85.  Majority of the units are 2 bedrooms .  Ownership has spent over $5M on cap ex exterior since they took over in 2020.  The interior units are pretty much original.  15 of the units have W&D’s and are getting a $100 bump.  Happy to chat through it.',TRUE,TRUE,''),
('Park Villas Apartments','6 - Passed','Phoenix-Mesa, AZ',205,1963,185365,38000000,NULL,'2025-03-12','2025-03-25','All Docs Saved - Jay, we are guiding to a 6.25% in-place cap rate (~38M+).  Let us know when you have time to discuss.',TRUE,TRUE,''),
('The Hudson','6 - Passed','Orlando, FL',320,2022,250000,80000000,NULL,'2025-03-12','2025-03-25','All Docs Saved 

JS: metrowest, 3.9 cap without live local credit

- Ethan – Hope you’re doing well, appreciate you reaching out.

 

On Hudson, we’re targeting the low $80 millions territory ($250Ks - $260Ks per unit) which yields a ± 5.25% cap rate on current leased rents (un-trended), ramping to ± 5.5% when marking the RR to current market rents which the property continues to achieve on active/recent leases without any concessions (last 3 leases by FP = $1,827/mo. avg).    Additionally, The Hudson benefits from being grandfathered into Florida’s Live Local Act tax abatement program (SB 102) with 89 of the 320 units (±28% of the RR) currently included in the program.  When factoring-in the current tax abatement the property receives from Orange County, an additional ± 30 bps of yield are generated on top of the cap rate metrics quoted above.

 

No CFO date has been circled as of yet, but we’d anticipate offers being due around early April timeframe.

 

We’re happy to hop on a phone call to share more of the backstory here.  Keep us posted with any questions in the interim, or if you’d like to schedule a tour of the community.',TRUE,TRUE,''),
('Broadstone Centennial','6 - Passed','Nashville, TN',261,2023,321839,84000000,NULL,'2025-03-11','2025-03-25','84MM - High 3 cap on in place
Was under contract 1031 buyer issues + rate spikes
Alliance built - probably not interesting',FALSE,TRUE,''),
('Arlo Buffalo Heights','6 - Passed','Houston, TX',318,2014,251572,80000000,NULL,'2025-03-05','2025-03-25','All Docs Saved -  "Pushing Hard for $80MM"',TRUE,TRUE,''),
('Cortland Seven Meadows','6 - Passed','Houston, TX',300,2015,233333,70000000,'2025-04-08','2025-02-26','2025-03-25','All Docs Saved - No OM - Is this in Cinco Ranch Proper?

Thank you for your interest in Cortland Seven Meadows in the Cinco Ranch Area.  We want to take a minute to point out a few things as you review this opportunity:
 
•	Differentiated Product - Large Units Attracting Families        
•	Cortland averages 1,057 SF / unit while the average square footage of all Class A properties in the Katy/Cinco Ranch/Waterside submarket is 973 SF, almost 100 SF smaller than Cortland Seven Meadows
•	Zoned to A+ rated Seven Meadows High School and Katy Independent School District (Katy ISD)        
•	This has led to a resident retention ratio of over 70%.
•	Consistent High Occupancy and Submarket Occupancy Growth
•	The property has consistently averaged more than 95% occupied over the past year
•	No Properties Under Construction in Area and Only Two in Lease-Up within 3 miles
•	Value-Add Opportunities- Cortland Seven Meadows has an array of modern 1, 2, and 3-bedrooms, with room to enhance the interiors further and drive up income. Potential renovation ideas include:
•	Outdoor Yards on 20 of the ground floor units at a premium of $100/month
•	Bulk Internet/Wifi for a net premium of $30/month net        
•	Continuation of the Vinyl Plank Flooring on all 2nd and 3rd floor units at a premium of $50 for 1BR units, $100 for 2BR units, and $150 for 3BR units
•	Kitchen backsplashes on all units for a $20/month premium         
•	A playground can be added as an additional property amenity due to over 300 kids at the property.        
•	$6,142 (77%) Monthly discount to rent vs. own in zip code 77494 
 
 
We are whispering $70 M for this asset. 
 
This is a great suburban, well-operating garden deal within a top 5 school district and submarket in the Houston MSA . Please reach out to schedule a tour or if you have any questions.',TRUE,TRUE,''),
('Briar Forest Lofts','6 - Passed','Houston, TX',352,2008,153409,54000000,'2025-04-01','2025-02-18','2025-03-25','All Docs Saved - Hey Ethan, 

$54M on this one.',TRUE,TRUE,''),
('Amber Pines at Foster’s Ridge BTR','6 - Passed','Houston, TX',124,2020,266129,33000000,NULL,'2025-03-04','2025-03-25','All Docs Saved - Fundrise bought from DR Horton 
Ethan
Guiding to $33M on this one; likely mid-fives year one. If you’re going to own one, this is it. Detached homes with the full yard-driveway-garage package that tenants are looking for. Excellent schools as well. Let me know what other info we can get to you. 

-Jim',TRUE,TRUE,''),
('Ravello Stonebriar Apartments','6 - Passed','Dallas-Fort Worth, TX',216,2018,289351,62500000,NULL,'2025-03-20','2025-03-25','All Docs Saved - Low to mid $60mm',TRUE,TRUE,''),
('Creekstone Apartments','6 - Passed','Dallas-Fort Worth, TX',213,1982,93896,20000000,NULL,'2025-03-13','2025-03-25','All Docs Saved - We anticipate Creekstone & Gablepoint to trade at the attractive basis of $34M – $36M ($91k – $96k/unit - sale comps attached). Built in 1982 and 1986, these assets have been owned, self-managed, and well maintained by the same family office owner for over 40 years (never sold before - original developer) and allows new ownership the rare opportunity to implement a first-generation value-add strategy: 

a.	Interior renovations: 96% classic units (Almond appliances and original cabinets) 
b.	Carport/Reserved Parking: Currently no reserved parking or carports (neighboring assets achieving $35/space with high occupancy)
c.	Washer & Dryer Sets: 212 unit have W/D connections, but property has not yet monetized off of including the machine sets in each unit ($50 premium).
d.	RUBS: Currently, the property is not receiving reimbursements on utilities, making it the last ABP property in the submarket. Residents pay their own electricity, and property pays for everything else. 
e.	Organic Rent Growth: Even with an ABP rent structure, rents are still below market

Furthermore, these properties are owned by the same owner / seller of The Greenville Three portfolio (Greenville Three Portfolio - IPA Dataroom), providing the optionality to acquire these assets as a portfolio as well.

Creekstone & Gablepoint sits right off I-635 and Furgeson Road in Far East Dallas and positioned only several hundred yards away from Dallas Athletic Club golf course. Within five miles radius of major employment hubs such as Baylor Scott & White Medical Center, Texas Instruments, and Amazon, while also providing residents with convenient access to premier retail and entertainment destinations including White Rock Lake, Casa Linda Plaza, and Town East Mall.

A CFO date has not been set yet but will likely take place in early April.

Please let us know if you have any questions or need any additional information. We have already started conducting tours onsite, so please let us know if you would like to schedule a property tour.',TRUE,TRUE,''),
('Gable Point Apartments','6 - Passed','Dallas-Fort Worth, TX',147,1986,95238,14000000,NULL,'2025-03-13','2025-03-25','All Docs Saved - We anticipate Creekstone & Gablepoint to trade at the attractive basis of $34M – $36M ($91k – $96k/unit - sale comps attached). Built in 1982 and 1986, these assets have been owned, self-managed, and well maintained by the same family office owner for over 40 years (never sold before - original developer) and allows new ownership the rare opportunity to implement a first-generation value-add strategy: 

a.	Interior renovations: 96% classic units (Almond appliances and original cabinets) 
b.	Carport/Reserved Parking: Currently no reserved parking or carports (neighboring assets achieving $35/space with high occupancy)
c.	Washer & Dryer Sets: 212 unit have W/D connections, but property has not yet monetized off of including the machine sets in each unit ($50 premium).
d.	RUBS: Currently, the property is not receiving reimbursements on utilities, making it the last ABP property in the submarket. Residents pay their own electricity, and property pays for everything else. 
e.	Organic Rent Growth: Even with an ABP rent structure, rents are still below market

Furthermore, these properties are owned by the same owner / seller of The Greenville Three portfolio (Greenville Three Portfolio - IPA Dataroom), providing the optionality to acquire these assets as a portfolio as well.

Creekstone & Gablepoint sits right off I-635 and Furgeson Road in Far East Dallas and positioned only several hundred yards away from Dallas Athletic Club golf course. Within five miles radius of major employment hubs such as Baylor Scott & White Medical Center, Texas Instruments, and Amazon, while also providing residents with convenient access to premier retail and entertainment destinations including White Rock Lake, Casa Linda Plaza, and Town East Mall.

A CFO date has not been set yet but will likely take place in early April.

Please let us know if you have any questions or need any additional information. We have already started conducting tours onsite, so please let us know if you would like to schedule a property tour.',TRUE,TRUE,''),
('Alexan Mill District','6 - Passed','Charlotte-Gastonia-Rock Hill, NC-SC',290,2024,280000,81200000,NULL,'2025-03-06','2025-03-25','All Docs Saved - Hey Ethan - We are shooting for $280k per unit which is a 5.0%+ cap on Y1 before factoring in bonus yield from Brownfield. Probably a ~20% discount to replacement today.',TRUE,TRUE,''),
('Springfield Apartment Homes','6 - Passed','Raleigh-Durham-Chapel Hill, NC',288,1986,156250,45000000,NULL,'2025-03-06','2025-03-25','All Docs Saved - 155-160k',TRUE,TRUE,''),
('Retreat on Lake Lynn Apartments','6 - Passed','Raleigh-Durham-Chapel Hill, NC',344,1986,194767,67000000,'2025-04-02','2025-02-27','2025-03-25','All Docs Saved - $67m or 5.5 t3 cap',TRUE,TRUE,''),
('The Riverside','6 - Passed','Washington, DC-MD-VA',23,1956,152173,3500000,NULL,'2025-03-06','2025-03-24','All Docs Saved',TRUE,TRUE,''),
('Berkeley House','6 - Passed','Washington, DC-MD-VA',48,1964,218750,10500000,NULL,'2025-03-06','2025-03-24','All Docs Saved -',TRUE,TRUE,''),
('Mallory Square','6 - Passed','Orlando, FL',284,2024,348591,99000000,NULL,'2025-02-13','2025-03-24','All Docs Saved - Guiding mid $300s per unit. Property is finishing its initial lease up – just hit 80% and should be stabilized by April/May. 
 
Most expansive amenity set in Lake Nona and interior finishes on par with a custom home. Their location on the north side up near the Country Club is strategic – immediate access to 528, near the original Lake Nona retail & restaurants, and away from the chaos/pipeline of Lake Whippoorwill/Narcoosee corridor.
 
Let me know if you’d like to chat through at all or if you need more intel.',TRUE,TRUE,''),
('The Museum Tower Apartments','6 - Passed','Houston, TX',187,2002,491978,92000000,NULL,'2025-03-06','2025-03-24','All Docs Saved - 92MM - Dustin Selzer',TRUE,TRUE,''),
('St. Tropez Apartments','6 - Passed','Fort Lauderdale-Hollywood, FL',376,1994,409574,154000000,'2025-04-01','2025-02-25','2025-03-24','All Docs Saved - Ethan…target on this is $410k per unit / $315 per sf. Thanks.',TRUE,TRUE,''),
('Holly Crest','6 - Passed','Charlotte-Gastonia-Rock Hill, NC-SC',402,2016,298507,120000000,NULL,'2025-03-04','2025-03-24','All Docs Saved - Holly Crest is 300k',TRUE,FALSE,'')
ON CONFLICT (name) DO NOTHING;

INSERT INTO deals (name,status,market,units,year_built,price_per_unit,purchase_price,bid_due_date,added,modified,comments,flagged,hot,broker) VALUES
('The Inverness','6 - Passed','Houston, TX',204,1990,166666,34000000,'2025-03-26','2025-02-20','2025-03-18','All Docs Saved - Ethan,
Pricing guidance on this is $34MM',TRUE,FALSE,''),
('Avalon Village BTR','6 - Passed','Fort Myers-Cape Coral, FL',148,2025,331081,49000000,'2025-03-26','2025-02-20','2025-03-18','All Docs Saved - Hi Ethan,

 

Great to hear from you on this one. This is a forward sale of a 148-home community of detached single-family homes. We expect first deliveries to be in August 2025 and deliver at a pace of 10-15 homes/month with final deliveries in Q2/Q3 2026. We are targeting pricing in the range of $330,000-340,000 per home, which equates to a stabilized untrended cap rate in the mid/high 6%’s.

 

Below are some quick highlights:

 

High-Quality Product: Solid concrete block construction across a mix of 3-, 4-, and 5-bedroom floor plans, all single-story with 2-car garages and private fenced-in yards. 48 of the homes surround a 6-acre pond at the center of the community. Note that the unit mix proposed in the OM is preliminary, and you will have the ability to adjust the unit mix (within reason).
Desirable, Heavily Undersupplied Location: Located in Lehigh Acres, a well-established suburb directly east of Fort Myers near several major hospitals, Southwest Florida International Airport, and a rapidly expanding logistics hub within Fort Myers. The Property sits along Homestead Rd, one of the main commercial corridors in Lehigh Acres with convenient access to numerous restaurants, big box stores, and Publix grocery. Currently, there is zero market-rate rental product in Lehigh Acres in a city with a population of 127,393. Lehigh Acres is projected to see 11.3% population growth over the next 5 years, a nearly 40% higher growth rate than Lee County.
Appealing Value Play: Similar homes in the area are selling for high $300,000’s to low $400,000’s, providing a substantial discount to retail value. A big boost to cash flow is the property millage rate here, which is only 11.6490, or nearly half of the typical millage rate in Florida. At the expected pricing, you will be achieving development-type returns without the development risk.
 

Let me know if you would like to jump on the phone to discuss in more detail.',FALSE,TRUE,''),
('Gramercy Square at Ayrsley','6 - Passed','Charlotte-Gastonia-Rock Hill, NC-SC',358,2009,237430,85000000,'2025-03-26','2025-02-21','2025-03-18','All Docs Saved - Guiding 240k/door. Low 5 cap in-place with clear value-add opportunity. Great Woodfield built product with a single owner/manager (Simpson Housing) since inception. The 78% classic units are low hanging fruit for upgrades. The 22% renovated units still have some value-add opportunity as well (backsplash, cabinet doors, lighting). Great floorplans including 18 carriage homes w/ attached garages and one of the only elevatored properties amongst its'' comp set.

CFO likely closer to the end of March.',TRUE,TRUE,''),
('Vida Lakewood Ranch','6 - Passed','Sarasota-Bradenton, FL',304,2023,296052,90000000,'2025-03-25','2025-01-27','2025-03-18','All Docs Saved - Ethan, 
Thanks for reaching out.   Sorry for the delayed response.  Digging out of my inbox after NMHC.   
The pricing guidance for Vida is $295,000 - $300,000 per unit.   This puts the in-place cap rate close to 5.0%.   There is immediate upside as the current rents could be raised $100 - $200 and still be below the comps.   As evidence of the rents being below market, the property leased up at 30 units per month with very minimal concessions.  It’s been over 95% occupied since April and currently stands at 99% leased.   The owners have managed the property very conservatively without raising rents despite the high occupancy.  
It’s also worth noting that the property is unique in the submarket being a two-story product with direct entry for every apartment.   As you may be familiar, Lakewood Ranch has been the fastest selling community in the county for several years in a row, and the surrounding demographics are outstanding.   
FYI, we should have the doc center ready to go early next week.  Let us know if you have any other questions. 
On a separate note, have you guys dug into The Easton Riverview, yet?',TRUE,TRUE,''),
('Resia Dallas West Apartments','6 - Passed','Dallas-Fort Worth, TX',336,2023,180059,60500000,'2025-03-19','2025-03-03','2025-03-18','All Docs Saved - Thanks for reaching out. Guidance is $180K PU which is a low 6% stabilized cap rate. We’re currently penciling March 19th as the CFO date. A few brief highlights below:
 
•	Developed by nationally acclaimed developer, Resia 
•	Superior micro-location providing accessibility to job nodes throughout the metroplex in Downtown Dallas, Irving, and Grand Prairie/Arlington 
o	Located 20-minutes from Downtown Dallas via easy accessibility to both I-35E and I-30. 
o	Situated near Dallas National Golf Club 
?	Within a 10-mile radius, residents have access to over 550,000 jobs 
?	Major employers include Lockheed Martin, General Motors, DFW International Airport, Texas Healthcare Resources, and major Fortune 500 companies in Irving including Vistra Energy, AT&T, Microsoft,  McKesson, and Fluor. 
•	High barriers to entry with 0 units in lease-up or under construction within a 3.5-mile radius of the property 
 
Let us know if you’d like to hop on a call to discuss further or schedule a tour.',TRUE,TRUE,''),
('The Carolyn','6 - Passed','Dallas-Fort Worth, TX',319,2019,242946,77500000,'2025-03-19','2025-02-14','2025-03-18','All Docs Saved - Upper 70MM Range',TRUE,TRUE,''),
('The Oakley','6 - Passed','Atlanta, GA',252,1990,123015,31000000,'2025-03-31','2025-03-05','2025-03-18','All Docs Saved - Hey Ethan,

Thank you for your interest in The Oakley. Its unit mix of 100% 2-, 3- and 4-bedroom floorplans (27% townhomes) with an average size of 1,268 SF is ideal for families and provides a distinct competitive advantage. The Oakley has undergone extensive repositioning with $8 million invested over the past 3 years and with an approximate 85% turn of the rent roll. The heavy lifting is done.
 
Price guidance is $31M - $32M or ~ $125k/U and $100/SF which equates to a stabilized cap rate of 7% before any value-add. 
 
Key highlights:
•	Situated amidst 131M SF of industrial/logistics space, 30% of the resident base works in this industry.
•	Capital improvements include new Hardie siding, all new roofs, common area enhancements and much more, thus, minimal cap ex needs for the next owner. 
•	Only one other community in micro-market with townhome floorplans, which provide headroom of $150-$200.
•	No true 4-bedroom competitors, headroom of $560+ to newer vintage.
•	Potential to upgrade 93% of the units for an additional monthly premium of $150.
•	Install washer/dryer sets in remainder of the units (237) for an additional $140k of annual NOI.',TRUE,TRUE,''),
('771 Lindbergh Apartments','6 - Passed','Atlanta, GA',204,1999,188725,38500000,'2025-03-25','2025-02-28','2025-03-18','All Docs Saved - Thanks for your interest in 771 Lindbergh & Lakeshore Crossing.  Here’s some additional color on both assets.

771 Lindbergh is 204 units built in 2000.  We expect it to trade in the $190’s a door which is approximately a 5 cap and will be delivered free & clear.

Lakeshore Crossing is almost adjacent to 771 and adds an additional 148 units built 1990.  We expect it to trade in the $170’s a door and is also approximately a 5 cap and available free & clear.

Both properties are still owned and self-managed by the original developer.  AHI exceeds $175K within 3 miles, and the rents are well below market.

Here’s a link to the website/deal room.  Let us know if you have any questions and when you would like to schedule a tour.',TRUE,TRUE,''),
('Lakeshore Crossing Apartments','6 - Passed','Atlanta, GA',148,1990,168918,25000000,'2025-03-25','2025-02-28','2025-03-18','All Docs Saved - Thanks for your interest in 771 Lindbergh & Lakeshore Crossing.  Here’s some additional color on both assets.

771 Lindbergh is 204 units built in 2000.  We expect it to trade in the $190’s a door which is approximately a 5 cap and will be delivered free & clear.

Lakeshore Crossing is almost adjacent to 771 and adds an additional 148 units built 1990.  We expect it to trade in the $170’s a door and is also approximately a 5 cap and available free & clear.

Both properties are still owned and self-managed by the original developer.  AHI exceeds $175K within 3 miles, and the rents are well below market.

Here’s a link to the website/deal room.  Let us know if you have any questions and when you would like to schedule a tour.',TRUE,TRUE,''),
('Washington Apartments II','6 - Passed','Washington, DC-MD-VA',200,1978,250000,50000000,NULL,'2024-12-06','2025-03-18','All Docs Saved -  Washington Apts

AM: we are closer to 40-45M to buy this

-	260-270 / door = low 50Ms
o	Said this is lower than was under contract for before
-	Loan assumption – 32.5M, FTIO through 2029
-	Mid 6 cap (taxes are already at 53M)',TRUE,TRUE,''),
('Tapestry Largo Station','6 - Passed','Washington, DC-MD-VA',318,2015,314465,100000000,'2025-03-13','2025-01-29','2025-03-18','All Docs Saved - Around $100m

Now is more like $95MM',TRUE,TRUE,''),
('Skye Suwanee','6 - Passed','Atlanta, GA',233,2020,283261,66000000,'2025-03-19','2025-03-06','2025-03-18','All Docs Saved - Ethan,

Appreciate you reaching out.

Pricing is $66M ($283K/Unit), which is a ~5.40% Year 1 cap rate.

This is 2020-built suburban town center product developed by Terwilliger Pappas and well-maintained by Barings, and priced well below replacement costs.

Suwanee Town Center is the most desirable location within one of North Atlanta’s best submarkets. The town center includes 187K+ SF of local restaurants/shops and the recently opened second phase brings an additional 38 acres of greenspace, parks, and wooded trails.

The property is performing well with 94% occupancy and has seen strong recent leasing trends.

When are you available to discuss and/or tour?',TRUE,TRUE,''),
('Zaterra Luxury Apartments','6 - Passed','Phoenix-Mesa, AZ',392,2023,349489,137000000,'2025-03-18','2025-02-10','2025-03-17','All Docs Saved - $350k per unit.',TRUE,TRUE,''),
('Mason Oliver Apartments','6 - Passed','Phoenix-Mesa, AZ',292,2016,212328,62000000,'2025-03-25','2025-02-21','2025-03-17','All Docs Saved - No OM - Jay – guidance is $62 - $64 Mln.',TRUE,TRUE,''),
('Estrella Gateway','6 - Passed','Phoenix-Mesa, AZ',240,2004,225000,54000000,'2025-03-14','2025-02-06','2025-03-17','All Docs Saved - Hi Jay, guidance is ±$225k per unit.  Yes that week works for us as well.',TRUE,TRUE,''),
('Seventh','6 - Passed','Phoenix-Mesa, AZ',286,1980,136363,39000000,'2025-03-12','2025-02-06','2025-03-17','All Docs Saved -  135-140k/unit',TRUE,TRUE,''),
('FLATZ 602','6 - Passed','Phoenix-Mesa, AZ',180,2023,220000,39600000,NULL,'2025-01-28','2025-03-17','All Docs Saved - Jay - Thank you for your interest in Flatz602.  We expect pricing to be in the $220K per unit range.  Let us know if you would like to schedule a call to discuss the property in more detail or if you would like to schedule a tour if you are going to be in Phoenix.
 
Please let us know if you have any additional questions or need additional information for your review.',TRUE,TRUE,''),
('Rosemary Glen Townhomes','6 - Passed','Greensboro--Winston-Salem--High Point, NC',121,2024,247933,30000000,NULL,'2025-03-14','2025-03-14','All Docs Saved - Thanks for signing the CA on Rosemary Glen.  Do you have interest here or pulling for tracking purposes?  I’ve pasted a collapsed locational summary below to ensure you have the full scope of the economic growth surrounding the property.
 
Guidance is $250K per unit – a 6.0% cap on in-place rents (with stabilized occupancy and expenses, in other words, a 6% stabilized return-on-cost). 
 
Property is 66% leased and they’ve had 8 gross and 7 net leases in February, not bad for winter.  We expect March, April, May and June to be double digit leasing months, setting up for a permanent financing execution instead of needing to go debt fund. @Grant Harris on our debt team can share more.  See attached Lease Up Projection.
 
Location Overview (with a map view attached):
 
•	The Triad’s geographic advantage is the backdrop for its economic expansion: Central location between Charlotte and Raleigh/Durham as well as equidistant between D.C. and Atlanta
o	The region is an epicenter for commerce growth, in-part, due to the 5 (+1 future) Interstates that run through it: 
?	I-40 (Triad to RDU, Winston-Salem and I-77 in Charlotte)
?	I-85 (Triad to Charlotte, Greenville, SC, ATL)
?	I-73 (Greensboro to Virginia, and south to hwy 74 toward Wilmington)
?	I-74 (Winston-Salem to High Point to Wilmington)
?	I-285 (Winston-Salem to I-85 to Charlotte, et al)
•	Future I-685 will connect the Triad to I-95
 
Surrounded by key economic centers (great location for split commuter households)
•	10 mins to Cone Health Regional Hospital
•	18 mins to Burlington and Elon University
•	20 mins to Greensboro
•	27 mins to Toyota Battery Facility
•	27 mins to Piedmont International Airport
•	38 mins to Wolfspeed Chip Facility 
•	40 mins to downtown Durham 
•	48 mins to RTP
•	48 mins to Winston Salem
•	49 mins to Raleigh-Durham International Airport
•	1.5 hours to Charlotte Douglas International Airport (top 5 busiest in US)
 
Economic Growth – just a sampling of the announcements (these jobs are arriving now or forthcoming)
•	Toyota Battery Plant (EV)
o	5,000+ jobs | $14 Billion investment | Greensboro (27 mins)
 
•	Boom Supersonic (Aerospace)
o	2,400 jobs | $32 Billion impact to NC | Greensboro (36 mins)
 
•	Marshall (Aerospace)
o	240 jobs | $50M project | Greensboro (36 mins)
 
•	VinFast (EV) - 2028
o	7,000 jobs | $4 Billion | Chatham County (38 mins)
 
•	Wolfspeed (chip manufacturing)
o	1,800 jobs | $5B investment | Chatham County (38 mins)
 
•	Ross Stores (retailer)
o	852 jobs | $450M investment | Randolph County (33 mins)
 
•	Indo Count (Textiles)
o	232 jobs | $15M investment | Greensboro (28 mins)
 
•	MetOx International (superconductors, AI)
o	333 jobs | $194M plant | Chatham County (38 mins
 
•	IQE (semiconductors, AI)
o	109 jobs | $305M plant | Greensboro (27 mins)
 
•	TopGolf (Triad’s first location)
o	300 jobs | Greensboro (28 mins)
 
From a lifestyle, retail, shopping standpoint https://spinosoreg.com/portfolios/alamance-crossing-2/ Alamance Crossing is one of the best performing lifestyle centers in the North Carolina, and its less than 5 mins away from Rosemary. Publix and Harris Teeter also right here.  And Lowe’s Foods, a top end grocer, is just 5 mins. 
 
Elon University
Experience significant growth, transforming from a small regional college into a nationally recognized private university. Enrollment has grown 70% since 2000, with 82% of students coming from out-of-state.  Its invested over $800 million in its campus since 2009 with several infrastructure upgrades.  Its faculty has increased 118% since 2000, outpacing student growth to maintain a low 11:1 student-to-faculty ratio.',TRUE,FALSE,''),
('Axis West Apartments','6 - Passed','Orlando, FL',268,2017,279850,75000000,'2024-10-08','2024-09-10','2025-03-14','All Docs Saved - Grand is $250k per unit, Axis West $280k  and Sands is $290k per unit.',TRUE,TRUE,''),
('Hawthorne at the Park','6 - Passed','Greenville-Spartanburg-Anderson, SC',234,1991,162393,38000000,NULL,'2025-02-17','2025-03-12','All Docs Saved  - Jay – Thanks for reaching out. Pricing guidance is $160k - $165k/unit which is a low to mid 5% cap and pushing close to 7% following the completion of the renovations in year 3. Hawthorne at the Park presents a unique opportunity to acquire an institutionally maintained, in demand 3-story walk up asset with accretive debt well below market (3.8% rate). Current ownership has spent almost $3M on the interiors/exteriors of the property, allowing new ownership to focus efforts on a Class-A renovation scope to match market comparables and push rents $250+.

 

The property is situated just East of downtown Greenville known for its strong demographics and ease of access to top retailers (Trader Joes, Whole Foods, Fresh Market) and major employment nodes such as BMW, Michelin, Inland Port Greer and the Greenville/Spartanburg International Airport. 

 

Long term ownership (13 years), but the go-forward business plan for them and their equity partner is to begin recycling capital on their assets that need renovations and the next level of value-add, and re-deploy into new build assets.

 

The OM should be available next week but let us know if you have any questions in the meantime. Have a great weekend!',TRUE,TRUE,''),
('Greenprint Gateway','6 - Passed','Salt Lake City-Ogden, UT',150,2023,193333,29000000,NULL,'2025-03-05','2025-03-12','All Docs Saved - Target on Gateway is $29mm.  

 

Really cool property – same owners as our www.ownsecondstate.com in Clearfield. Target on Second State is $24mm.  

 

Both incredible opportunities – let me know if you want to jump on a call to discuss.

 

We have not set a CFO yet, but will most likely be in mid-to-late April.',FALSE,TRUE,''),
('Washington Apartments III','6 - Passed','Washington, DC-MD-VA',200,NULL,NULL,NULL,NULL,'2024-12-09','2025-03-06','Phase III',FALSE,TRUE,''),
('Reserve South Apartments','6 - Passed','Richmond-Petersburg, VA',200,1987,165000,33000000,'2025-03-19','2025-02-07','2025-03-06','All Docs Saved - Hey Ethan – below is the spiel, let me know if it makes sense to jump on a call to discuss.

Guiding to $33-34m or $165k/unit. This basis feels really good compared to some recent sales in this submarket that traded on both a higher per foot and per unit basis. 

Doc Center: Doc Center with OM, DD items, etc.: https://clientportal.berkadia.com/opportunities/006Pf00000MAN3XIAX

Overview:? 
•	200 Units, Built in 1987. All large 2-bed and 3-bed floorplans which has led to low turnover across the property
•	With normalized bad debt we are shaking out around a upper 5% CAP on T3/T12 tax and insurance adjusted financials 
•	Nearby Class B renovated rents are averaging ~$300 greater than Reserve South 
o	Ownership partially renovated 108 units but all 200 are primed for a next level renovation 
•	Through the last 10 years ownership has invested a total of $3.9M ($19,400/unit) of capital via a wide range of both income and non-income generating items
•	Nearby Employment Hubs:
o	Boulders Office Park (under 2 miles away): Features over 1 million square feet of office space with a diverse mix of publicly traded companies in sectors such as business services, health sciences, and engineering.  
o	Chippenham Hospital (less than 1 mile away): A Level 1 Trauma Center within the HCA Healthcare System, employing over 2,000 staff and housing 466 hospital beds.
o	Richmond Downtown Core (78K+ jobs) and within immediate proximity to the explosive Old Town Manchester area that is home to a bustling restaurant and entertainment scene 
•	Since 2015, effective rent growth in the Southside Submarket has averaged 5.4% annually, and latest Axiometrics projections project 4.7% annual growth through 2029. 
•	Property rents also introduce the possibility for advantageous agency financing initiatives. 
•	There is a bit of vacancy and bad debt noise on the T-3 which we don’t have anymore.  Project is 94+% occupied and 96+% leased.  Annualizing T3 bad debt is 8.5% as they wrote off/evicted late payers recently.  The current AR balance is $104k or 2.8%.  They’ve employed a new screening software late last year as well as dropped their outstanding balance threshold for evictions from $1,000 to $500 and it’s working.',TRUE,TRUE,''),
('525 Avalon Park','6 - Passed','Orlando, FL',487,2008,285420,139000000,'2025-03-12','2025-02-20','2025-03-06','All Docs Saved - Guidance is $285-290k per unit, $204-208 PSF.',TRUE,TRUE,''),
('Hayes House','6 - Passed','Nashville, TN',201,1927,268656,54000000,'2025-03-19','2025-02-10','2025-03-06','All Docs Saved 

 - Jay – 

Guidance on this one is in the $54/55mm range at this point. Sentinel is the seller and they purchased the asset in 2019. It’s an exceptionally well-located asset on 21st avenue, walkable to Hillsboro Village, Vanderbilt, etc and located in a very insulated pocket with no new supply in the immediate area. 

-	Phase I (1924) consists of 98 units. only 2 of the units are renovated, so there is plenty of opportunity to improve these units over time, specifically with kitchen finishes. There is hardwood flooring throughout. 
-	Phase II (1997) consists of 103 units. 69 of these have been renovated, leaving 34 in classic condition. 
-	Like most assets in the urban areas of Nashville, supply has impacted operations over the last couple of years. However, with deliveries dropping rapidly and virtually nothing new starting, we anticipate this being a year when the market transitions and begins to firm up, with 2026 being the first of several years of strong rent growth.  

We haven’t set an offer date yet, but its likely going to be around the 2nd week in March. Please let me know if you’d like to schedule a time to discuss in more detail. Michael Stepniewski is running the debt on this one for us, so if you start to dig in and think you may pursue, I can connect you with him to help dial in the best debt options.',TRUE,TRUE,''),
('Cordoba','6 - Passed','Miami, FL',454,2010,429515,195000000,'2025-03-12','2025-02-20','2025-03-06','All Docs Saved - Ethan,

Guidance on Cordoba is around $430k per door, which works out to a 5% in-place cap with reassessed taxes, concessions burned off and normalized vacancy. Vacancy was a little higher than 5% in the trailing numbers due to units being held offline for renovations, and the property has maintained occupancy of 95% or better on the available units. There is also an opportunity to introduce a bulk wi-fi package onsite.

With the core+ upside fully baked in, it’s closer to a 6%-cap.
 
Let us know if you’d like to arrange a tour or discuss further. 
 
All the best,
Kaya',TRUE,TRUE,''),
('District West Gables','6 - Passed','Miami, FL',427,2015,334894,143000000,'2025-03-13','2025-02-26','2025-03-06','All Docs Saved - Target pricing is $335k per unit, 5.25 cap.  Waterton has put in about $2.5mm in capital in the deal in the last 2 years.  Let’s get a tour set up.  Copying Danny for debt quotes.  Offers will be due March 13th.',TRUE,TRUE,''),
('Villas at Stonebridge Ranch Apartments','6 - Passed','Dallas-Fort Worth, TX',280,1998,178571,50000000,'2025-03-12','2025-02-06','2025-03-06','All Docs Saved - The Strike price is low-$50 million range. Let me know if you would like to set up a tour.',TRUE,TRUE,''),
('Pinnacle Apartments','6 - Passed','Washington, DC-MD-VA',115,2024,321739,37000000,NULL,'2025-02-12','2025-03-06','All Docs Saved - Guidance is $37M --- stabilized 6% Cap.',TRUE,TRUE,''),
('Ventura Villas','6 - Passed','Tucson, AZ',312,1989,105769,33000000,NULL,'2025-02-20','2025-03-06','All Docs Saved - Hi Ethan,
 
Thank you for your interest in Ventura Villas, a 312-unit, attractive loan assumption opportunity located in Tucson, AZ. (CA: Deal Room link). Ventura Villas is a scaling opportunity to acquire assets with exceptional in-place operations and substantial upside via continuing/initiating value-add interior renovations and/or capitalizing on mark-to-market rent increases. More info on the offering below.
 
Pricing Breakdown:
Property:	Units:	Pricing:	Per Door:
Ventura Villas	312	$33,000,000	$105,769
			
 
Deal Stats/Timing: 
•	Guidance: Breakdown above (free and clear)
•	Current Occupancy: 96% 
•	Tours: Please reach out to Emily Leisen to schedule onsite tours
•	Call for Offers: To be Announced 
 
 
Deal Highlights
High Performing Assets with Tremendous Upside
•	Outstanding in-place operations deliverable at a high in-place cap rate 
•	Attractive loan assumption opportunity with a blended rate of sun 4.8% 
•	High historical occupancy performance suggests that rents can increase organically on renewals
•	Blank-Canvas Value-Add Opportunity: 
o	Opportunity to renovate 100% of classic interiors and capitalize on potential rental premiums of ±$125/month 
o	Organic rent growth opportunity as average submarket rents for one-bedroom units are $54 higher and two-bedroom units are as much as $123 higher/unit/month 
o	Opportunity to increase current flat rate RUBS fees as submarket competitors are nearly $20/unit/month higher than Ventura Villas 
•	Ownership invested over $420,000 into capital improvements into Ventura Villas: 
o	roof maintenance, office and clubhouse, parking lot, sidewalk repairs, stairway beams decks, laundry room, office/clubhouse, exterior paint, pool fence, landscape improvements
 
Community Amenities
•	Swimming Pool 
•	Basketball Court
•	Playground
•	Remodeled Laundry Room 
•	Leasing Office 
•	Clubhouse 
 
Location Highlights
•	Located in Tucson, AZ that has an expanding population of approximately 1.08 million, a nearly 1% increase since 2023, placing Tucson #4 out of twelve western MSA’s from growth
•	In the past 12 months Tucson employment has grown by 1.4% and employers have added 5,600 works to payrolls 
•	The properties are proximate to several of Tucson’s largest employers including The University of Arizona, Davis-Monthan Air Force Base, Raytheon, IMB, Casino del Sol, and the Tucson International Airport 
•	Within 10 miles of the UA Tech Park, a ±1,267-acre university research park, which is home to over 100 companies, over 2 million square feet of office, laboratory, and production space, and has an economic impact of over $52.8 million annually 
•	UA Tech Park is home to high wage, high tech jobs with employers including IBM, Raytheon, and Applied Energetic 
•	Located near the new American Battery Factory development which will create an estimated 1,000 jobs in South Tucson 
•	New transit is underway next to the property: the Tucson Norte-Sur transit-oriented development will run from Tucson Mall in the north to Tucson International Airport in the south and is aimed at enhancing transit and spurring economic development 
•	Within three miles of the Tucson Spectrum Shopping and Entertainment Center which is home to over 1 million square feet of big box retail and restaurants including Target, Home Depot, JC Penny, Ross, Best Buy, Michael’s, Marshall’s, Office Max, PetSmart, Burlington Coat Factory, Five Below, Old Navy, Harkins Theaters, Sprout’s Farmers Market and more 
•	A multibillion-dollar sports and entertainment complex, The Mosaic Quarter, is coming to South Tucson and will provide space for youth and adult recreational and collegiate athletic programs and is expected to generate billions of dollars in revenue over the next 40 years 
 
Major Area Drivers (all within 5-30 minutes)
•	UA Tech Park – Link
•	Davis-Monthan Air Force Base – Link 
•	Tucson Spectrum Shipping Center – Link 
•	University of Arizona – Link
•	Tucson International Airport – Link 
•	Desert Diamond Casino – Link 
•	American Battery Factory – Link 
•	Mosaic Quarter – Link
•	Downtown Tucson',TRUE,TRUE,''),
('Camden Midtown Apartments','6 - Passed','Houston, TX',337,1999,185014,62350000,'2025-03-05','2025-02-06','2025-03-06','All Docs Saved - Hey Ethan – we are whispering $62.35MM here which is around $185k/u. Let us know if you have any questions as you dig in. Thanks!',TRUE,TRUE,''),
('Marcella Memorial Heights','6 - Passed','Houston, TX',380,2001,240000,91200000,'2025-03-05','2025-02-20','2025-03-06','All Docs Saved - Ethan,

 

Guidance is $240k/unit ($200 psf), 5.25%-5.35% going in today with $1200/unit for insurance.  Seller just renewed 2025 at $1140/unit.  There are significant value add opportunities on the interiors and adding bulk wifi/cable.  Seller’s upgrade premiums are averaging $300 on 166 units.  We are solving to a 6-cap year 1 after upgrading half of the remaining unit interiors and adding bulk cable/wifi.  

 

Let me know if you have any follow up questions or would like to setup at tour.',TRUE,TRUE,''),
('Ocotillo Bay Apartments','6 - Passed','Phoenix-Mesa, AZ',296,1996,304054,90000000,'2025-02-13','2025-01-14','2025-03-06','All Docs Saved - Jay - guidance is $90 Mln.  In-place cap rate is north of 5%, FY 1 cap rate is 5.65% and stabilized mark-to-market cap rate is 6.2%.

2/13/25 - Offered $76MM',TRUE,TRUE,''),
('Soltra Kierland','6 - Passed','Phoenix-Mesa, AZ',202,2024,549504,111000000,'2025-02-04','2024-12-17','2025-03-06','All Docs Saved - Hi Jay - Guidance is $111M which is a 5.5% stabilized cap rate',TRUE,TRUE,''),
('Park at Winterset Apartments','6 - Passed','Baltimore, MD',176,1999,244318,43000000,'2025-03-18','2025-01-23','2025-03-06','All Docs Saved  - Around $43m',TRUE,TRUE,''),
('Summerlake Villas','6 - Passed','Tampa-St. Petersburg-Clearwater, FL',228,2003,153508,35000000,'2025-03-20','2025-02-20','2025-03-06','No Docs Yet
Summerlake Villas – 228 units 2003
o	But he said its “an absolute dumpster fire”
o	$12MM in renovations, but they kicked out all the residents to do so
o	No renovation tracker etc.
o	Said it is basically a lease up deal at this point
o	Rental Asset Mgt is seller, and they want to be done with it, only asset in that market
o	Guiding to $155k/door = ~$35MM',TRUE,FALSE,''),
('Alta at the Farm','6 - Passed','Dallas-Fort Worth, TX',325,2024,261538,85000000,'2025-03-06','2025-01-27','2025-03-03','All Docs Saved - Pricing guidance is low to mid $260k/unit. The asset just reached stabilization and is seeing an 8% increase on lease tradeouts. 

Let us know if you have any additional questions.',TRUE,TRUE,''),
('Ashton at Judiciary Square Luxury Apartments','6 - Passed','Washington, DC-MD-VA',49,2011,408163,20000000,'2025-03-06','2025-02-19','2025-02-25','All Docs Saved - Low to mid 20''s',TRUE,TRUE,''),
('Massachusetts Court Apartments','6 - Passed','Washington, DC-MD-VA',371,2005,377358,140000000,'2025-03-06','2025-02-19','2025-02-25','All Docs Saved - Low to mid 140''s',TRUE,TRUE,''),
('Yorkshire Apartments','6 - Passed','Washington, DC-MD-VA',326,1990,269938,88000000,'2025-03-11','2025-01-22','2025-02-25','All Docs Saved - Hi Jay – hope you’re well too. Guidance is upper-$80MMs (~$270K/Unit) – high-5% cap rate in-place with compelling assumable debt ($64.3MM loan proceeds, 3.33% fixed rate, May 2030 maturity).',TRUE,TRUE,''),
('Cobblestone on The Lake Apartments','6 - Passed','Fort Myers-Cape Coral, FL',248,2008,221774,55000000,'2025-03-04','2025-02-05','2025-02-25','All Docs Saved - Thank you for reaching out on this one. Cobblestone on the Lake was originally built to be condos in 2008,  with full concrete-block construction, podium-style parking with direct elevator access in the majority of the units, and a significant portion of the property consisting of townhome units with 2-car garages. This asset offers significant value-add potential with nearly 100% of the units currently in their original condition. 
 
Pricing Guidance:
•	$55M / $221,774 per unit / $166 per SF (~40% below replace cost)
•	Seller is willing to carry a hope note (can explain in more detail over a phone call)
•	5.50% in-place cap rate (tax/insurance adjusted)
•	7.00%+ proforma cap rate upon completion of interior value-add strategy ($300 upside potential w/ 100% units currently in classic condition)
•	17-19%+ IRR
•	Note that there are an additional 42 units located in two buildings that are still in shell condition. Those can either be brought back online or scraped to make way for additional amenities.
 
Truly Distinguished Among Comp Set:
•	1,330 SF average unit size (largest units in market)
•	10 foot ceilings
•	Concrete block construction
•	90% of units are two- and three- bedroom floorplans
•	22% of units are three-story townhomes with attached two-car garages
•	Private elevator access in all units excluding townhomes',TRUE,TRUE,''),
('Apex SouthPark','6 - Passed','Charlotte-Gastonia-Rock Hill, NC-SC',345,2020,NULL,NULL,NULL,'2025-02-14','2025-02-25','All Docs Saved -',TRUE,TRUE,''),
('Solana Place at Carlton Commons','6 - Passed','Phoenix-Mesa, AZ',113,2023,274336,31000000,'2025-02-27','2025-01-27','2025-02-25','All Docs Saved - Thank you for your interest in Solana Place at Carlton Commons, a 113-home, institutional-quality true-detached Build-to-Rent community built by the nation’s largest homebuilder, DR Horton. (CA: RCM Deal Room Link). Solana Place at Carlton Commons is a rare opportunity to acquire a true detached two-story home community with two-car garages and private backyards located just 30 minutes from the Greater Phoenix MSA and strategically situated half-way between the Phoenix and Tucson markets. More details on the offering below:
•	Pricing Guidance: $31,000,000 ~ ($274,336/door)
•	Pro Forma Cap Rate: 6.88% 
•	Tours: Please reach out to Emily Leisen to schedule onsite tours
•	Financing: Please reach out to Brandon Harrington and Bryan Mummaw to discuss new financing options 
•	Call for Offers: TBD
 
Deal Highlights:
Irreplaceable Legacy Asset with Tremendous Rent Growth Story
•	The asset experienced exceptional organic in-place rent growth since the first lease was signed in November 2023 compared to the leases signed in January 2025 with an actual in-place rent increase of $250 or 14.5%
•	Tremendous lease renewal activity with rent increases of 6%+ and an average conversion rate of nearly 80% from January to March of this year 
•	Beautifully crafted three- and four-bedroom homes built by D.R. Horton, the nation''s largest single-family homebuilder
 
Highly Desirable Product/Elevations
•	113-home, luxury community featuring 8ft ceilings throughout, enclosed backyards with concrete patios and beautiful landscaping, and attached two-car garages with private driveways
•	Unix mix consists of three-bedroom homes (69% of property) & four-bedroom homes (31% of property) with an average unit size of 1,381 sf
•	Each home contains full size W/D, stainless steel appliances, granite countertops, shaker styler cabinets, vinyl plank flooring, 2” horizontal blinds, glass walk-in showers, double sink vanities, and walk-in closets with built-in shelving
•	Fully equipped Smart Home Technology Package with keyless entry, doorbell cameras, Smart thermostats, and home alarm system
 
Location Highlights: 
•	Casa Grande is strategically positioned near the I-10 and I-8 highways providing exceptional inter-state connectivity, which fuels the economy for manufacturing, distribution, and logistics industries 
•	Conveniently positioned halfway between the Phoenix and Tucson MSA’s, the two largest MSA’s in the state by population
•	The connectivity between Phoenix and Tucson allows businesses and residents to access the amenities, workforce, and markets of both metropolitan areas within an hour’s drive 
•	Lucid Motors electric vehicle manufacturer strategically selected Casa Grande as the site for its Advanced Manufacturing Plant 1 which currently employs over 2,000 workers and is the catalyst for economic growth in the region
•	There are several major manufacturing and logistics employers that support thousands of jobs in Casa Grande including the Abbott Laboratories, Walmart Distribution Center, Frito-Lay Inc., Daisy, Hexcel, Graham Packaging, Cardinal Glass Industries, and Cargill 
•	Banner Health has recently invested in expanding their 141-bed Banner Casa Grande Medical Center, which will add new wings and expand services such as cardiology, oncology, and maternity care 
•	There are several economic developments underway in Casa Grande which will boost the economy and propel job growth including the Grande Valley Industrial Project which will rezone 2,250 acres to industrial use, the Central Arizona College expansion, the FrameTec manufacturing facility, and a 600-acre mixed-use development that is will be built near the I-10 and will include industrial space, retail offerings, and a data center
 
Major Economic Drivers (within 5-30 minutes):
•	Lucid Motors – (Link)
•	Banner Health – (Link)
•	Abbott Laboratories – (Link)
•	Historic Downtown Casa Grande – (Link)
•	Walmart Distribution Center – (Link)
•	Frito Lay Inc. – (Link)
•	Kohler Distribution Center – (Link)',TRUE,TRUE,''),
('The Retro on 32nd Street Apartments','6 - Passed','Phoenix-Mesa, AZ',64,1968,129687,8300000,NULL,'2025-02-06','2025-02-25','8.3MM',TRUE,TRUE,''),
('Metro 8','6 - Passed','Phoenix-Mesa, AZ',8,2023,NULL,NULL,NULL,'2025-02-06','2025-02-25','',FALSE,TRUE,''),
('The Flats','6 - Passed','Phoenix-Mesa, AZ',112,1975,147321,16500000,NULL,'2025-02-05','2025-02-25','All Docs Saved - Guidance is ±$16.5M, T12 6.25% cap rate and fully stabilized, untrended 7.00%.',TRUE,TRUE,''),
('Pearl Midtown','6 - Passed','Houston, TX',154,2014,185064,28500000,'2025-02-19','2025-01-08','2025-02-25','All Docs Saved - $28.5mm is guidance here Jay.  $185k/unit.  30-40% below replacement cost',TRUE,TRUE,''),
('8001 Woodmont','6 - Passed','Washington, DC-MD-VA',322,2021,590062,190000000,NULL,'2024-09-09','2025-02-20','All Docs Saved - Guidance is +/- $190MM inclusive of retail and tax abatement. Low to mid 5% blended in place cap rate unabated, high 5% abated.

 

Let us know if you’d like to discuss or set up a tour.',TRUE,FALSE,''),
('Latitudes at the Moors','6 - Passed','Miami, FL',358,1990,259776,93000000,NULL,'2025-01-30','2025-02-19','All Docs Saved - Ethan,

Guidance on Latitude is around $260k per door, which works out to a 5.5% in-place or a 6%+ cap post-renovation.

Nuveen is the seller and has invested millions in capital since they bought it from DWS back in 2018.

Concrete tile roofs were replaced in 2013 and the property is zoned for A-rated schools.

Let us know if you want to jump on a call to discuss further or arrange a tour.

All the best,
Kaya',TRUE,TRUE,''),
('Touchstone at Little Valley','6 - Passed','Salt Lake City-Ogden, UT',125,2024,384000,48000000,NULL,'2025-02-05','2025-02-18','All Docs Saved - Ethan,
 
Thank you for your interest in Touchstone at Little Valley, a premier 125-unit build-to-rent townhome community in Magna, Utah. This newly delivered D.R. Horton-built asset is nearly stabilized after a strong lease-up, and presents an exceptional opportunity to acquire best-in-class rental townhomes in a rapidly growing submarket.
•	Pricing Guidance: $48M, reflecting a 5.61% cap rate on the stabilized Year-1 Going-In NOI. 
•	Mission Based Financing: Note that the property has naturally occurring affordability and qualifies for mission-based preferential agency pricing. Please let us know if we can connect you with our debt team to discuss financing options.
•	Tours and Call for Offers: Call for offers will be toward the beginning of March. Please contact our team now to schedule a tour.
•	Phased Delivery & Strong Lease-Up: The community was delivered in phases between May 2024 – December 2024 and has already achieved over 80% occupancy and is over 90% leased.
•	Consistently Rising Rents: The latest leases are being signed at over 18% higher rates than when the property first launched leasing. There is robust rent growth and demand.
•	High-Quality Construction: Developed by D.R. Horton, the townhomes feature direct-access two-car garages, spacious floor plans averaging 1,475 SF, quartz countertops w/ tile backsplash, stainless steel appliances, and smart home technology.
•	Prime Market Fundamentals: Magna is experiencing rapid population growth, significant infrastructure investments, and a strong renter demographic with an average household size of 3.35, making these townhomes highly desirable.
•	Strategic Location: The property benefits from excellent freeway access via SR-201 and Mountain View Corridor, proximity to the Utah Inland Port (expected to drive 30,000+ new jobs), and major employment centers nearby and across Salt Lake County.
•	Visit the deal Landing Page if you have not already accessed the offering materials. 
With a strong lease-up trajectory and a stabilized path to full occupancy, Touchstone at Little Valley represents a rare opportunity to acquire a newly built, high-performing rental townhome community from the nation’s strongest homebuilder.
 
Please let us know if you’d like to schedule a tour or discuss this opportunity further.',TRUE,FALSE,''),
('Maple Grove BTR','6 - Passed','',66,2023,315151,20800000,NULL,'2025-02-03','2025-02-18','All Docs Saved - Great to hear from you and it was good to see Kees & Will out at NMHC.  We are targeting $20.8m or $315k per unit for Maple Grove which shakes out to be a 5.75% cap rate on our proforma and a 5.35% cap on in-place.  The property is a brand new built-to-rent deal in the northern suburbs of Richmond where homes are selling a $400k+.  The property is a 55+ community with no delinquency and quality resident base.  These units are part of a master-planned community and is fully financeable by the agencies.  There is a lot to like about this deal.  Let us know if you would like to setup a call to discuss in greater detail or would like to schedule a tour.

 

I hope all is well and look forward to catching up with you soon.',TRUE,TRUE,''),
('The Views at Laurel Lakes','6 - Passed','Washington, DC-MD-VA',308,1987,246753,76000000,NULL,'2025-02-06','2025-02-18','All Docs Saved - Pricing is around $76M.',TRUE,TRUE,''),
('Millworks Apartments','6 - Passed','Atlanta, GA',345,2017,234782,81000000,'2025-02-25','2025-01-22','2025-02-18','All Docs Saved - Thanks for your note. Guidance on Millworks is $81M or $235K/unit. This is a compelling investment opportunity for several reasons:

 

Repositioning Opportunity - Ability to renovate common areas (exterior paint, FF&E, corridors) and close the $300-400 rent spread to the adjacent new product
Affluent resident demographic can absorb renovation premiums – Avg HHI is $125K (17% rent:income)
ATL is a non-strategic market for the owner, who self manages. This is their only asset in the MSA and planning to exit the market
Resilient Operations – Currently 97% occupied with a 60-day trend of 96%. Effective recent lease growth of +5.0%. Limited bad debt and concessions
Accretive Assumable Debt - 4.15% (amortizing) with three years of remaining term (~70% LTV)
Discount to Replacement Cost – 30%+ discount to replacement cost. Adjacent podium asset was capitalized at $360k/unit
 

We’d be happy to discuss in more detail and/or schedule a time to meet on-site at your convenience.',TRUE,TRUE,''),
('Acadia on the Lake Apartments','6 - Passed','San Antonio, TX',304,1982,106907,32500000,NULL,'2025-02-07','2025-02-18','William –
 
I hope that you are doing well. Would love to catch up and hear more about your overall strategy and where you are trying to deploy capital. After 8 years in Investment Banking and Real Estate Private Equity, I went out on my own to focus on residential and medical office acquisitions and would love to see if there are any synergies. I wanted to share this deal with you and see if it could be a good fit for your capital.
 
My partner and I just went under contract on a 304-Unit multifamily property in San Antonio, TX called Acadia on the Lake. Starting on Monday February 10th, we will have a 30-Day DD (one 15-day extension) and 30-day close thereafter. We are buying the property from a distressed seller that bought the property for ~$40m [ + spent additional $2m on unit upgrades ($1.6m) + capex ($400k) ] in 2022 with floating rate debt coming due April 2025 and is forced to sell. The seller loan basis is $31.3m and we are purchasing the property for $32.5m essentially wiping out his equity. 
 
The property was built in 1982 and is located in the Northeast San Antonio submarket. 
 
Our going in cap rate is 6.36%, however in summer of 2024 12 units were impacted by a fire from a charcoal grill left on a porch, creating 12 down units which will be rebuilt by June 2025 (fully paid by the insurance) so really our going-in cap rate adjusted for the 12 fire units is 6.90% (June 2025 unit delivery vs April close).
 
We are looking to raise ~$17m LP Equity. Open to a Co-GP structure as well.
 
Investment Highlights:
•	Property Overview:
o	Units: 304 units with an average unit size of 821 SF.
o	Year Built: 1982
o	Unique Property Amenity: Adjacent to an 18-acre park offering walking trails, a lake for fishing and recreational amenities.
•	Acquisition Metrics:
o	Purchase Price: $32.5M ($106.9K/unit)
o	Cap Rate: 6.36%
o	Cap Rate Adjusted for 12 Down Fire Units: 6.90%
o	Post-renovation Untrended yield on cost: 7.63%
•	Project Level Returns (5-Year Hold):
o	Levered IRR: 19.4%
o	Equity Multiple: 2.12x
•	Value-Add Strategy:
o	Value-Add Business Plan: The business plan would be to renovate the interior of units with hard stone counters, modern shaker style cabinet doors, SS appliances, lighting, plumbing fixtures, and luxury vinyl plank flooring. This will bring the property in line with renovated comps in the market, which show a ~$200-$250 rental upside.
o	Current Light Renovation: Currently there are 151 lightly renovated units are achieving $100-$150 premiums proving renovation upside. These lightly renovated units have vinyl counters and old cabinets showing that that there is additional rental upside for a superior renovation scope.
o	Insurance Proceeds for Fire Units: In May 2024 12 units were impacted by a fire from a charcoal grill left on a porch, creating 12 down units. Currently these units are being demolished and in the process of being rebuilt with insurance claim proceeds of ~$3M and are expected to deliver in June 2025. Given the brand-new build for the 12 units, the Sponsor is underwriting a $100 premium for newly constructed units vs renovated units.',FALSE,TRUE,''),
('Cortland Bayside','6 - Passed','Tampa-St. Petersburg-Clearwater, FL',360,2020,375000,135000000,'2025-02-27','2025-01-22','2025-02-18','All Docs Saved - Jay,

We’re guiding to $375k/unit, which is around a 5% on inplace adjusted',TRUE,TRUE,''),
('Marlowe South Tampa','6 - Passed','Tampa-St. Petersburg-Clearwater, FL',350,2024,331428,116000000,'2025-02-27','2025-01-27','2025-02-18','All Docs Saved - $116M, $331k per unit, 5.25% year 1.',TRUE,TRUE,''),
('The Easton Riverview Apartments','6 - Passed','Tampa-St. Petersburg-Clearwater, FL',300,2023,276666,83000000,'2025-02-20','2025-01-06','2025-02-18','All Docs Saved - 
Hi Jay,

Thank you for reaching out regarding The Easton Riverview. Pricing guidance is $83 million to $86 million ($275,000 - $285,000 per unit) which yields a cap rate of ~5.3% based on in-place rents, an elimination of concessions as the submarket stabilizes and accounting for the grandfathered Live Local Act tax abatements that the property receives from Hillsborough County.   The deal underwrites to a low teens IRR with new debt and offers strong upside potential in a submarket poised for rent growth with new supply plummeting. Additionally, an investor can further increase the property’s NOI by maximizing the number of units included in the Live Local Act tax abatement program. Currently, 102 units are included in the program, but 161 units qualify, and by including these additional 59 units in the tax abatement program, the in-place yield increases by an additional ~20 bps.    We see the deal hitting a 6% cap in year 2 or 3 based on anticipated rent growth as the submarket rebounds. 

As noted in the teaser, The Easton is situated in the high-growth Brandon/Riverview submarket of Southeast Hillsborough County and benefits from the area’s exceptional quality of life, convenient access to Downtown Tampa and the Brandon office market, and proximity to a wide array of entertainment and recreational options. Additionally, the property is the only apartment community within the Belmont master plan, which blends a mix of attractive residential subdivisions, parks, schools and a Publix-grocery anchored retail town center adjacent to The Easton.

We will start touring the asset next week and we also expect to have the OM finalized and a populated data room by early next week.

Let us know if you have any further questions.',TRUE,TRUE,''),
('Greenwich Oaks','6 - Passed','Stamford, CT',134,1970,1119402,150000000,NULL,'2025-02-03','2025-02-18','All Docs Saved -both properties are approx. 5% in place cap rate, roughly $150mm for Oaks and $220mm for Place. Same seller so both can be acquired together (or separately).',TRUE,TRUE,''),
('Greenwich Place Apartments','6 - Passed','Stamford, CT',272,1976,808823,220000000,NULL,'2025-02-04','2025-02-18','All Docs Saved - both properties are approx. 5% in place cap rate, roughly $150mm for Oaks and $220mm for Place. Same seller so both can be acquired together (or separately).',TRUE,TRUE,''),
('Independence Place Apartments - Prince George','6 - Passed','Richmond-Petersburg, VA',229,2011,187772,43000000,NULL,'2025-02-03','2025-02-18','All Docs Saved - Thank you for your interest in Independence Place Prince George, a 230 Unit / 2011 vintage asset with attractive assumable HUD financing in place and offered for sale by the original developer in the Richmond MSA. 
 
Independence Place Prince George presents investors with a well-positioned asset poised for an ideal value-add opportunity which will take the property to the next level. Independence Place Prince George offers a unique spectrum of unit furnishing options ranging from classic to all-inclusive and fully furnished units ready for instant move-ins. The property is conveniently located off Interstate 295, giving residents immediate access to all major employers, retail, and demand drivers across the Richmond MSA. 
 
The asset is located within 1 mile of one of the largest military bases in the country, Fort Gregg-Adams, which presents new ownership with a reliable gold-plated tenant base. Limited supply in the Prince George area, coupled with ideal market fundamentals have provided the opportunity for Independence Place to increase rents markedly through value-add renovations
 
Please review the information below and let us know if you have any questions after reviewing all offering materials. See the details regarding pricing expectation and tour process below.  Thank you. 
 
----
 
OM & DD Docs: OM, T12, Rent Roll, etc. Link to Data Room here: Independence Place Prince George - Website
 
Pricing Guidance: $43,000,000 or $187,000/unit which represents a 5.6% cap on T3 Income / T12 Expenses.
 
Call for Offers Date: Wednesday, March 5th, 2025
 
Property Tours: Property tours will be offered as requested, with 48 hours advance notice required. Please let us know when you would like to schedule a tour and we will accommodate.   
 
Address & Google Map
5000 Owens Way, Prince George, VA 23875
Google Maps Link
 
Summary and Investment Highlights:
•	Attractive Assumable In-Place HUD Financing:
o	Original Principal: $25,034,600
o	Current Principal: $24,306,972
o	1st Payment Date: 9/1/2022
o	Fixed Interest Rate: 4.66%
o	Maturity: 9/1/2057
o	Amortization: 35 Years
•	Unique Spectrum of Unit Furnishing Options
•	Well-Positioned Asset Poised for Value-Add Opportunity
•	Impactful Military Presence Driving Local Economy | Low Multifamily Supply
•	Excellent Location Proximate to Demand Drivers',TRUE,TRUE,''),
('Metropolis at Innsbrook Apartments','6 - Passed','Richmond-Petersburg, VA',402,2023,248756,100000000,'2025-03-05','2025-01-22','2025-02-18','All Docs Saved  - Completed in late 2024, the property consists of 402 units and currently 90% occupied/95% leased.
Located in the heart of Innsbrook which features 22,000 employees and 500+ companies
Proximate to an abundance of retail along the Broad Street corridor and Short Pump
Significant upside to increase rents on renewals and second-generation leases to compete against similar Class A+ product in the submarket
Pricing guidance: $100,000,000 ($249,000 per unit)',TRUE,TRUE,''),
('Copper Run BTR','6 - Passed','Raleigh-Durham-Chapel Hill, NC',141,2025,347517,49000000,NULL,'2025-02-06','2025-02-18','All Docs Saved - 
Jay,

 

Thanks for reaching out. Pricing guidance is in the $350k per door range. Please see the high-level overview of the offering below:  

 

Copper Run // 141 Units // Built 2025 // Durham, NC

 

Rare forward sale townhome opportunity located in-between Durham and Raleigh on NC 70.
Unit mix consists of large three-bedroom townhome units (~1,715 sf) which all include a one car garage, 9’ ceilings and rear patios. Additionally, there are six (6) single family detached units with a two-car garage.
Unit interiors boast top of line finishes including smart home security systems, LVP flooring, stainless steel appliances, granite kitchen countertops and quartz bathroom countertops, ceramic tile backsplashes, LED lighting packages, white shaker style cabinets with satin nickel hardware and soft close hinges, and walk-in closets with wired shelving.
First units are set to deliver in early May 2025.
Copper Run is ideally located near Triangle’s most coveted employment center, Research Triangle Park (0.2 miles, 65k jobs). RDU International Airport is also located four miles south.
Residents will also enjoy the close proximity to Brier Creek Commons, an 800K square foot shopping center that includes Target, Dicks, TJ Maxx, Total Wine, BJ’s, Alpaca Peruvian Chicken, Chilis, and Chic fil a. There is also a new Publix grocery store less than a mile west of the property.
The average household income in the area is $100k+
 

Please let us know if you have any questions. Let’s hop on a call to discuss when you’ve had a second to dive in.',FALSE,TRUE,''),
('Isles at East Millenia','6 - Passed','Orlando, FL',200,1985,160000,32000000,'2025-03-12','2025-02-12','2025-02-18','All Docs Saved - Targeting low $160K’s per unit which is north of a 6% cap on in-place, adjusted for taxes. Do you want to set up a call to discuss?',TRUE,TRUE,''),
('Alta Deco','6 - Passed','Orlando, FL',297,2024,319865,95000000,'2025-02-19','2024-12-10','2025-02-18','All Docs Saved - Ask price is around $95M, which is +/-$320k per door. On their in-place rents, it''s a low 5% and year 1 will be between a 5.25-5.5% with 3rd party projected rent growth and a reduction in concessions once stabilized, given the lack of future supply in the submarket. 

 




 

This is one of the nicest deals in South Orlando, located adjacent to Darden Restaurant''s HQ and less than 5 minutes from 4M SF of suburban office parks as well as the new Epic Universe Theme Park which will open in May 2025 and bring nearly 15K new jobs to the market.  The product is extremely well executed and features interior conditioned corridors with elevators as well as interiors that include quartz countertops, soft close grey shaker-style cabinetry with undermount lighting, oversized kitchen islands with built in storage, upgraded Whirlpool stainless-steel appliances featuring indoor ice and water dispensers and front control ranges.  

 

The Property’s infill location in the heart of South Orlando benefits from minimal future supply as there is only one other deal under construction within the submarket and nothing planned beyond that. Additionally, the asset sits just east of the intersection of John Young Parkway and the 528 Expressway which provides strategic accessibility to the major job centers to the west in the tourist corridor as well as quick access east to the Orlando International Airport and Lake Nona. Proximity to these diverse employment centers is evident and translates through to the onsite demographics as average household incomes on site are $113K+.

 

Please let us know what questions you have as you review or if you’d like to schedule a tour of the property. As mentioned, the OM will be available in early January.',TRUE,TRUE,''),
('Tapestry at the Realm','6 - Passed','Dallas-Fort Worth, TX',362,2024,243093,88000000,NULL,'2025-01-27','2025-02-18','All Docs Saved - We expect Tapestry at the Realm to trade between $88M to $91M ($245k-$250k per unit. Tapestry was developed by Bright Realty in 2024 and sits within the 324-acre master-planned Realm at Castle Hills community in Lewisville, an area that has seen 50% population growth over the past decade.

The property is surrounded by over 1,000 acres of master-planned retail, office & entertainment centers including Grandscape, The Realm, and Crown Centre. Combined, these hubs include over 2 million square feet of both office and retail space and attract over 20 million visitors annually.

Following delivery of first units in February 2024, Tapestry experienced an impressive lease up averaging approximately 35 leases per month while gradually increasing average per square foot rents. 
A CFO date has not been formalized but we expect it to take place in late February. 

Let us know if we can answer any questions or set up a tour.',TRUE,FALSE,''),
('Hall Street Flats','6 - Passed','Dallas-Fort Worth, TX',340,2018,225000,76500000,'2025-02-26','2025-01-14','2025-02-18','All Docs Saved - Pricing guidance is mid-upper $220k/unit, which is significantly below replacement cost for intown wrap product. Let us know if you have any additional questions.',TRUE,FALSE,''),
('Fusion at Neon','6 - Passed','Norfolk-Virginia Beach-Newport News, VA-NC',239,2024,271966,65000000,NULL,'2025-02-12','2025-02-18','All Docs Saved - Hey Ethan – 

Good to hear from you and hope you guys are doing well. Please see rundown below, let me know if you have any questions or when you’re good to jump on a call.

This is an incredibly unique opportunity in a very strategic pocket of Norfolk. Below are some of the high-level bullet points to take into consideration. No CFO date as of now, will let you know as we get closer. 
-	There is highly accretive assumable debt at 3.54% with leverage that will be in the low to mid 70% range based off where pricing goes. VHDA is the lender, and while the debt is fully amortizing, it doesn’t mature until 2058. 
-	We’re guiding to $65M, which is a mid-5% cap on year 1 UW due to the nature of the lease up. Strong positive leverage at stabilization. We’re pretty significantly below replacement cost, especially for this product of 4 story with elevators, over 1 floor of structured parking. 
-	The location is at main and main, walkable to Sentara Hospital, Eastern VA Medical School, Downtown Norfolk, Ghent, and the retail along Colonial Avenue. As mentioned previously, we are one of the only properties in the market with dedicated parking and are having no trouble leasing up those spaces at $100/space. 
-	The amenity set exceeds our competitors, with multiple lounge areas as well as workspace locations; a game room; luxury pool and pet yard (very uncommon in this location); state-of-the-art gym yoga studio and Peloton studio, rooftop clubroom and terrace, as well as a courtyard yoga lawn. 
-	The market is doing exceptionally well, especially on the new product side. Currently, we are witnessing the lowest amount of deliveries in over a decade, with no sign of change. Less than 1.5% of the entire inventory in the greater market is under construction at this time, see below:',FALSE,TRUE,''),
('Banyan Grove','6 - Passed','Norfolk-Virginia Beach-Newport News, VA-NC',288,2003,243055,70000000,'2025-03-06','2025-01-24','2025-02-18','All Docs Saved - Hi Ethan, thanks for inquiring.

Deal highlights below:
-	Guidance $70M+; adjusted in-place cap rate 5.6%, year 1 6.15%   
-	Wood Partners constructed deal, institutionally maintained with significant recent capital infusion
-	86% of the property is unrenovated, average leased rents for renovated units $371 greater than classic rents (41 unit renovations completed)
-	Virginia Beach consistently outperforms national fundamentals; nonexistent supply pipeline driving rents with submarket occupancy 95%
-	Recent lease trade-outs 4.8% on new leases / 4.5% on renewal leases in last 45 days (during winter leasing slow down!)

Deal room should be built out with OM and statements early next week, we will make sure to send an email to let you know when this is available.',TRUE,TRUE,''),
('The Highlands at Morris Plains Apartments','6 - Passed','Newark, NJ',116,2003,344827,40000000,NULL,'2025-01-16','2025-02-18','All Docs Saved - Guidance is $40M+. Let me know if you have any questions',TRUE,TRUE,''),
('The Nashville Portfolio','6 - Passed','Nashville, TN',497,2023,219315,109000000,NULL,'2025-02-05','2025-02-18','Signed CA - Jay, great to hear from you.  Thanks for looking at the portfolio – the upside and discount to replacement make these compelling. 

Before guidance, here are obligatory, but IMPORTANT, investment highlights (don’t skip, you will be tested on them:)

•	New, high quality with Upside: Built by a local developer with a personal mission to provide affordable housing, this portfolio offers high-end finishes such as 10’-ceilings, stainless steel appliances, granite counters, and LVT but with efficient designs and scaled amenities to enable below market rents.  However, with no official rent restrictions in place, a new owner can immediately move rents to market comp levels.  The portfolio average-rent is in the $1,400/month range while nearby comps are $1,800+/month.

•	Market Recovery in Progress: Nashville''s suburban supply peak is over.  No new units within nine miles of The Crockett and only 72 units left to absorb in Nolensville/East Brentwood has reduced the need for concessions due to increasing demand.  Rents on new leases are up 3% over the last 90 days.

•	Rent Growth Potential: The properties have decreased concessions 25% over the past month with plans to reduce further during the spring leasing season.  Combined with the loss-to-lease burn off, as the properties turn first generation leases, provides significant rental upside to the next owner.

•	Prime Location in High Growth neighborhoods: Close to Nashville''s job hubs – The Crockett is just 15-20 minutes from downtown, the airport, and Mt Juliet Providence, while 6228 Music City and The Anderson are 15-20 minutes to key suburban job centers in Brentwood and Cool Springs.

•	Cost Advantage: Offered at low-$220,000/unit, these properties are significantly – up to 20% – below replacement cost for suburban, wood-frame properties.  The lower basis offers downside protection while providing an unassailable position as the luxury value leader of the area.

•	Flexible Purchase Options: Properties available individually or as a portfolio.

The entire portfolio should trade between $109 - $112M.  On year one, stabilized numbers, that is a low- to mid-5% cap.

I expect a Call for Offers in about four weeks.  Call me with questions or to schedule a tour.',FALSE,TRUE,''),
('Westshore Palm Bay','6 - Passed','Melbourne-Titusville-Palm Bay, FL',248,2023,241935,60000000,'2025-02-19','2025-01-07','2025-02-18','All Docs Saved - Guidance on Westshore Palm Bay is $60M+ ($242K PU / $241 PSF) which equates to an in-place cap rate of 5.50% using current collections, T3 other income and normalized expenses – and a 5.75% Year 1 cap rate. Westshore Palm Bay offers to opportunity to acquire a fully stabilized, new construction asset in the premier Space Coast submarket located just minutes from some of the area’s top employers including L3Harris, Northrup Grumman, and Collins Aerospace.

The 248-unit community, built in 2023, is strategically located along the I-95 corridor which offers direct access to I-95 providing seamless connectivity to major economics hubs including Orlando, Miami, and Jacksonville – all within a 3-hour drive of the Property. The Property also benefits from its proximity to Melbourne Orlando International Airport and Port Canaveral, which each welcomed over 740,000 and 4M passengers, respectively, in 2023. Additionally, Westshore Palm Bay is located minutes from the Hammock Landing Shopping Center, the area’s premier open-air mall featuring over 750,000 SF of retail, dining, and entertainment destinations that welcomed over 7.8M visitors in 2023.

Some additional investment highlights include:

Top Orlando MSA submarket with High Growth: From 2010-2024 the area has experienced 21% population growth within 1-mile of the Property, with another 4% increase expected by 2029.
Exceptional Tenant Demographics: Residents at the Property boast an impressive average household income of ~$95,000, indicating a strong, high-end demographic.
High-Quality, Stabilized New Construction Asset: The Property currently exhibits an impressive 96% leasing rate and 94% occupancy, highlighting its excellent performance and sustained capacity to maintain occupancy levels of over 90%.
Video Tour Link >>> https://vimeo.com/1041855729/639e72dbe7

Please let us know if you would like to set-up a call or schedule a tour.',TRUE,TRUE,''),
('Lakeside Apartments','6 - Passed','Houston, TX',296,2001,162162,48000000,NULL,'2025-01-10','2025-02-18','All Docs Saved, No Official Launch Yet - $48MM range with a nice loan to assume at 3.48%.',TRUE,TRUE,''),
('The Ivy','6 - Passed','Houston, TX',297,2017,397306,118000000,NULL,'2025-01-23','2025-02-18','All Docs Saved - Hi Jay—Pricing guidance here is ~$400k/unit, which equates to a ~4.5% in-place cap rate (adjusted for rent roll leased % (95%), taxes and ins). The offering includes in-place assumable financing at a ~3.5% fixed-rate coupon, full-term I/O, ~3 yrs remaining.',TRUE,TRUE,''),
('The Collective at Archer','6 - Passed','Gainesville, FL',172,2023,302325,52000000,NULL,'2025-01-28','2025-02-18','All Docs Saved - $52 million',TRUE,TRUE,''),
('The Lucie at Tradition','6 - Passed','Fort Pierce-Port St. Lucie, FL',264,2024,284090,75000000,'2025-03-06','2025-01-22','2025-02-18','All Docs Saved - 

Target pricing on this one is $285,000 per unit. Would you like to arrange a tour?',TRUE,TRUE,''),
('Venetian','6 - Passed','Fort Myers-Cape Coral, FL',436,2018,231651,101000000,NULL,'2025-01-28','2025-02-18','All Docs Saved - Hi Ethan 
$232k per unit',TRUE,TRUE,''),
('The International at Valley Ranch','6 - Passed','Dallas-Fort Worth, TX',236,2024,216101,51000000,'2025-02-20','2025-01-23','2025-02-18','All Docs Saved - We expect International at Valley Ranch to trade in the $50M-$51M ($212k-$216k per unit range). This property is four-story, elevator-served product with 236 units and had final CO in the first half of 2024 with a very strong lease-up at over 30 leases per month in the trailing 3 months. 

Located in Irving, the property is a part of the Valley Ranch master-planned community which is located near the I-35E and I-635 intersection bordering Coppell, Las Colinas, and Farmers Branch. Valley Ranch spans 2,440 acres and the average home price is $644k+. This is an extremely supply constrained market with International Valley Ranch being the only asset to deliver in the past 10 years and nothing is currently planned or under construction.

Being only a couple minutes from the President George Bush Turnpike, International at Valley Ranch is less than a 15-minute drive from major entertainment and employment hubs like Las Colinas, Cypress Waters, Grapevine, and DFW Airport. 

The call for offers date will be February 20th. Please let us know if you have any questions or would like to schedule a tour.',TRUE,TRUE,''),
('Aura 3Twenty','6 - Passed','Dallas-Fort Worth, TX',320,2024,259375,83000000,NULL,'2025-02-04','2025-02-18','Guidance is in the $260k’s per unit, it is a merchant build and we are approaching stabilization. We think that this is a mid-5 cap year 1. Key comp is Jefferson at the Grove, but this deal has a significant corridor access garage component that JATG did not have. Will be glad to discuss…

 

Aura 3TWENTY Apartments – Investment Highlights

Exceptional Multifamily Product Opportunity: Completed in 2024 by Trinsic Residential Group, featuring modern luxury amenities including granite countertops with undermount sinks, stainless steel appliances, soft-close cabinets, assignable corridor access garages, fitness center, pool, and clubhouse.
Prime Location in McKinney, TX: Situated in a fast-growing, affluent area of the Dallas/Fort Worth Metroplex with a 2024 population of 218,846, growing faster than the nation at 2.5% annually. Ranked #1 by Money Magazine in 2014 for "Best Places to Live in America."
Top-Rated Frisco ISD: Located in the A+ rated Frisco Independent School District, ranked #7 in Texas, driving tenant demand.
Lower Property Tax Advantage: Collin County offers structurally lower property tax rates compared to Dallas County.
Upside Potential: All 320 units have W/D connections. W/D machines have been added to 245 of the units, leaving an opportunity to add W/D machine sets to 75 units for additional rent.
Affluent North Metro Dallas Lifestyle: Surrounded by retail, restaurants, and entertainment, with excellent transportation and infrastructure access.
Proximity to Major Employment Hubs: Less than 10 miles from key DFW employment centers like Legacy Business Park, Hall Office Park, and the Platinum Corridor.
Neighboring High-Value Homes: Nearby single-family homes range from $500K–$1.3M, with Craig Ranch median home values at $560K.
Significant Commercial Development:
Medical City McKinney: $142M expansion underway.
TPC Craig Ranch: Hosts the AT&T Byron Nelson PGA Tour event.
PGA Frisco Headquarters: Includes two championship golf courses, Omni Resort, and conference center.
Universal Parks & Resorts: New theme park in North Frisco.
The Link: Mixed-use development with greenspace connectivity to PGA Frisco.
The Star: NFL Cowboys HQ and Frisco ISD shared facility
 

Thank you for your interest in Aura 3TWENTY apartments in McKinney, Texas.',TRUE,TRUE,''),
('The Casey at Frisco Station','6 - Passed','Dallas-Fort Worth, TX',300,2024,290000,87000000,'2025-02-27','2025-01-27','2025-02-18','All Docs Saved - $87-$89M is guidance.',TRUE,TRUE,''),
('5540 Hyde Park by 3L Living','6 - Passed','Chicago, IL',187,1936,85561,16000000,NULL,'2025-01-20','2025-02-18','All Docs Saved - Hey Ethan – Ask is like $85k per unit but we have a pretty motivated seller.  Please let me know if you want to hop on a call to discuss.',TRUE,TRUE,''),
('Nantucket Cove Apartments','6 - Passed','Champaign-Urbana, IL',240,2006,179166,43000000,NULL,'2025-01-21','2025-02-18','All Docs Saved - Hey Ethan – Hope all is well and thanks for reaching out! Please sign the CA if you haven’t already. Guidance is $43M which is a tax adjusted 5.4% cap and a Y1 6% cap. 57% LTV with the loan assumption.  

Let me know if you have any additional questions and happy to jump on a call to further discuss.',TRUE,TRUE,''),
('Wynfield Trace','6 - Passed','Atlanta, GA',146,1988,198630,29000000,NULL,'2025-02-06','2025-02-18','All Docs Saved - Details are below - very clean asset in strong suburban North Atlanta location with large floorplans (83% 2/3 BR) and assumable debt. 
 
Wynfield Trace // Peachtree Corners, GA // 146 Units // Built 1988
•	Link to Confidentiality Agreement for Financials: 
•	Guidance:
•	$29M-$30M ($200K-$205K/door) which is a mid-5% tax-adjusted in-place cap rate, with the ability to be pushed north of 6.50% through light value-add.
•	Asset Highlights:  
•	Occupancy: 91%, Avg. Mkt Rent: $1,806 ($1.48/ft). 
•	Wynfield Trace presents the opportunity to assume attractive in-place debt well below current market levels. The current in-place loan is offered at 4.44% interest with 3+ years of I/O remaining and 8+ years of term remaining.
•	A new owner has the opportunity to substantially grow rents by implementing a light interior value add program across all units. 
•	Submarket Highlights:   
•	Positioned in one of Atlanta’s most sought-after submarkets, Peachtree Corners, Wynfield Trace benefits from a strong surrounding demographic composition and strong multifamily fundamentals. 
•	Residents of Wynfield Trace benefit from exceptional connectivity to Atlanta’s prominent job nodes, including Technology Park, Perimeter Center/Pill Hill, and outer lying Gwinnett County.
•	Neighboring large-scale developments backed by Gwinnett County’s economic initiative have helped catapult Gwinnett County to the most influential, growth-oriented county in the Atlanta',TRUE,TRUE,''),
('Apex SouthPark - Retail','6 - Passed','Charlotte-Gastonia-Rock Hill, NC-SC',1,NULL,NULL,NULL,NULL,'2025-02-14','2025-02-17','Retail',FALSE,TRUE,''),
('Peavine Crossing & Stonehenge','6 - Passed','Birmingham, AL',312,2025,NULL,NULL,'2025-02-26','2025-02-14','2025-02-14','All Docs Saved - BTR Cap Rate Tracker

Hey Ethan - Guiding $280-$290k per unit, which is a 6.25-6.50% stabilized YOC which is 75 bps~ above where I think your stabilized cap rate would be. We sold Oak Tree in Chelsea for a 5.6% cap rate (only 55 units, vinyl exteriors) and we sold Timber Leaf around a 5.7% cap rate stabilized (inferior location / schools). Normal conditions I would put this in the 5.25-5.50% cap rate exit. 
 
Happy to talk through the forward structure more in-depth on a call if you aren’t familiar with it, great way to achieve opportunistic yields while removing development risk.',FALSE,TRUE,''),
('NEO at Midtown Apartments','6 - Passed','Dallas-Fort Worth, TX',321,2004,180685,58000000,'2025-02-13','2025-01-12','2025-02-13','All Docs Saved - 
Jay – Likewise and thanks for reaching out. Pricing guidance here is high-$50mm (low/mid-$180k/unit), which equates to a ~5% in-place cap rate (tax/ins/reserve adjusted).

1999 and 2013 Build',TRUE,TRUE,''),
('Clary''s Crossing','6 - Passed','Baltimore, MD',199,1984,226130,45000000,'2025-02-11','2024-09-17','2025-02-10','50 mil +

JP Morgan bought w LC3 and runs high occupancy, low rents (per Margerum)

First presented to us by CBRE as Off Mkt in 9/2024

On Market as of 12/12/24, 

$46M to $48M - 12/12/24 - Brian Margerum


Zach Stone:
-	Guidance 45M
-	Over 4% trade outs on last 25 leases
-	5.75% cap (current RR – in-place expenses, not tax adj)
	Taxes will be released in January (for next 3 years)',TRUE,TRUE,''),
('Heritage Apartments','6 - Passed','Raleigh-Durham-Chapel Hill, NC',144,2000,163194,23500000,NULL,'2025-02-04','2025-02-06','All Docs Saved - Jay – Great catching up a minute ago. As mentioned, please let us know if we can ever be a resource for you on the BOV front here in the Carolinas, even if it’s for internal purposes. Always happy to help.
 
Here is everything on the Heritage deal. The property was built in 2000 and is 144 units. 30% of the units are rent restricted until 2031, and the restrictions are not tied to any specific units. Docs for that are attached. Pricing here needs to be mid to high $23M and the seller is ready to make a deal. 
 
The property is currently in the county and not in the city, so their water expense is really high. The county water rate is $22/1,000 gal and the city rate would be $11/1,000 gal. You can go through the annexation process, which we have been led to believe is fairly straightforward, and it has also been done on a number of communities nearby. Your tax bill would increase and offset some of this. As you study that, make sure you remove the County Fire bill as that would go away as well. 
 
The current owner bought this in early 2021 and has a floating rate loan with Argentic. He was previously self managing and had some challenges there but brought on Harbor Group who has done a nice job stabilizing the asset within the past year. He was able to negotiate an extension with Argentic until summer of 2025 and has an agency refi lined up but would prefer to sell and move on. 
 
Let us know what else you need as you dig in.',TRUE,TRUE,''),
('The Louis Apartments','6 - Passed','Washington, DC-MD-VA',273,2014,410256,112000000,NULL,'2025-01-22','2025-01-30','Signed CA - No Docs yet - $110 - $115M…. Mid 5% Cap in-place.',TRUE,FALSE,''),
('The Premier','6 - Passed','Washington, DC-MD-VA',160,2014,259375,41500000,NULL,'2024-12-06','2025-01-29','$41.5m Original developer and this is their only multi deal. Solid asset with great upside. 
no docs yet 12/10',TRUE,TRUE,''),
('Perse by Trion Living','6 - Passed','Orlando, FL',384,2008,234375,90000000,'2025-02-12','2024-12-19','2025-01-28','All Docs Saved - 
CFO likely week of Jan 20
Guidance on Perse Apartments is $90M+ ($235K PU / $208 PSF) which equates to an in-place cap rate of 5.50% using current collections, T3 other income and T12 expenses – and a 6.10% Year 1 cap rate. Perse offers the opportunity to acquire a core-plus asset with significant value-add upside, of the 384 total units, only 14 are “fully renovated”, leaving new ownership with the opportunity to upgrade the remaining 370 classic units to the full renovation scope. The amenities at the Property have also remained largely untouched presenting the ability to transform the former Disney classrooms into amenity-rich spaces that elevate the overall tenant experience and appeal of the property.

The 384-unit community, built in 2008, is located right off of I-Drive in the heart of Orlando’s tourist corridor. The Property’s location provides immediate access to I-4 and SR-417 ensuring direct connectivity to Orlando’s premier economic drivers, including Walt Disney World, the city’s largest employer with over 77,000 employees as well as Orlando’s Central Business District which employs over 87,000. Additionally, Perse is located just 5-minutes from the Orlando Vineland Premium Outlets, Florida’s largest outlet shopping destination with over 770,000 square feet of retail, dining, & entertainment destinations that welcomes more than 17 million visitors annually.

Some additional investment highlights include:

Core-Plus Opportunity with Proven Value-Add Upside: Perse offers new ownership tremendous upside as 95% of units are available for renovations. Upgrading 100% of the remaining units will yield estimated premiums of $400+/month on average.
Abundant Unused Amenity Space Prime for Repositioning: The four large former onsite classrooms present a prime opportunity for transformation into value-adding amenity spaces.
Strategic opportunity to enhance the Property’s access by completing new entrance directly off International Drive: Plans to complete this project have already been approved leading to more convenient access to major thoroughfares I-4 and SR-417.
 Video Tour Link>>> https://vimeo.com/1035335950/5cf72bb3bf?share=copy

Please let us know if you would like to set-up a call or schedule a tour.',TRUE,TRUE,''),
('The Reserve at Wescott','6 - Passed','Charleston-North Charleston, SC',288,2004,208333,60000000,NULL,'2025-01-16','2025-01-27','All Docs Saved - Will and Kees, great seeing you this morning in Charlotte. Always enjoy catching up with you. 

As discussed, please find attached financials for Reserve at Wescott and below for a brief deal summary. This is off-market so timing is of the essence and please keep close to vest. This is a great physical product with 9ft ceilings and over $9M recently infused including all but 46 units upgraded to a top tier level. Summerville is currently soft because of all the supply but that will absorb and begin to dwindle in 2025/26.  Lots of upside in rents once that happens. Asking price is well below replacement cost. 

Guidance is $60M. 

Reserve at Wescott | Summerville, SC | 2004 Build | 288 Units 
•	Website: https://www.reservewescott.com/
•	Address: 4976 Wescott Blvd, Summerville, SC 29485
•	Unit Mix:
o	72 - 1 Bed/1 Baths | 779 Avg SF
o	48 – 1 Bed/1 Baths | 865 SF 
o	10 – 2 Bed/2 Baths | 1,044 SF 
o	42 - 2 Bed/2 Baths | 1,048 Avg SF 
o	26 - 2 Bed/2 Baths | 1,064 Avg SF 
o	8 - 2 Bed/2 Baths | 1,106 Avg SF 
o	16 - 2 Bed/2 Baths | 1,126 Avg SF 
o	30 - 2 Bed/2 Baths | 1,146 Avg SF 
o	36 – 3 Bed/2 Baths | 1,284 SF 
•	Value-Add: Renovated units are achieving up to a $270+ premium with quartz countertops, SS appliances, 9 ft ceilings, white shaker cabinets, backsplash, vinyl wood flooring, and new lighting/plumbing fixtures.
o	Floor plans with “r” (i.e. 1a2r) are renovated units. Floor plans without are classic (i.e. “.B2”)
•	Exterior Amenities: State of the art fitness center, resort-style swimming pool, resident clubhouse, oyster shack with fire pit and lawn games, outdoor grilling stations, quarter-mile trail surrounding lake, interactive outdoor fitness stations, bark park, garages, 24-hour locker system, valet trash, and much more.
•	CapEx: Ownership has spent over $9.3M in interior and exterior CapEx since 2021.
•	Investment Highlights:
o	Blue Chip Demographics: $89K+ Average Household Income (2 Miles)
o	Palmetto Commerce Park: 5,000K Jobs 1.4 Miles away | Manufacturers include Boeing, Mercedes Benz, FedEx Supply Chain, Cummins Turbo Tech, Marolina Outdoor (Huk), CBX Global, and many more.
o	Summerville Medical Office District: 2 Miles Away
o	Booming Charleston Economy: <20 minutes from Downtown Charleston. <20 Miles from +178K jobs including Charleston MSA industry drivers Joint Base Charleston (24,000 employees), MUSC (17,000 employees), Boeing (+7,800 employees), and Roper St Francis Hospital (6,100 employees). +30 New Residents Move to the Charleston MSA everyday (3x the national average). Ranked #3 on UHaul’s Top Growth Cities 2023.',TRUE,TRUE,''),
('The Whitney Apartments','6 - Passed','Salt Lake City-Ogden, UT',264,2025,NULL,NULL,NULL,'2025-01-22','2025-01-27','All Docs Saved - Forward Purchase Multi',FALSE,TRUE,''),
('Izzy Apartments','6 - Passed','Salt Lake City-Ogden, UT',133,2024,338345,45000000,NULL,'2025-01-22','2025-01-27','All Docs Saved - Ethan,

Thank you for your interest in The Izzy Apartments. This newly constructed, 133-unit property in Salt Lake City’s Sugar House neighborhood offers an exceptional investment opportunity. Below is some guidance and deal highlights. We look forward to discussing!
Pricing Guidance: $45M, representing a 5.45% on the Pro Forma NOI and a 5.22% cap rate on the As-Is Stabilized NOI. See the OM for full context on these analyses and please reach out to our team to discuss.
Status: Completed in 2024, the property has had strong demand and is approaching stabilization.
Call for Offers and Tours: A call for offers date has not yet been set, but please contact our team to schedule a tour. This is a one-of-a-kind Sugar House community that should be toured to be fully appreciated.
Prime Location: Nestled in the vibrant Sugar House area, this is one of the closest rental properties to the brand new Sugar House Trader Joe’s. Overall, residents enjoy walkable access to premier shopping, dining, and the S-Line Trax station.
Modern Design: Awarded 2024’s Most Outstanding Small Mixed-Use Project by Utah Construction & Design, Izzy Apartments features luxurious studios, one-bedroom and two-bedroom apartments, as well as two-story townhomes, all crafted with premium materials and upscale finishes.
First-Class Amenities: Residents benefit from two fitness centers, a rooftop lounge, co-working spaces, and more. The South building includes a restaurant retail space (signed LOI), enhancing the property’s dynamic appeal.
Market Demand: With robust lease-up momentum and high demand in Sugar House, The Izzy is poised to benefit from consistent rental growth and tenant appeal.
Please visit www.ownizzyapts.com to view some additional details and to access the OM and financials if you have not already done so.
We are excited to share more details about this rare offering in one of Salt Lake City’s most sought-after neighborhoods. Please let us know if you would like to schedule a tour or have any questions.',TRUE,TRUE,''),
('Skyway Towns - BTR','6 - Passed','Orlando, FL',84,2025,357142,30000000,'2025-01-24','2025-01-07','2025-01-27','All Docs Saved - Target pricing on Skyway Towns is ± $30 million ($360,000 per unit range), or lower 6% cap rate territory on un-trended pro forma.   This basis represents a healthy discount to recent “for sale” 3BR townhome comps, which average north of $455,000 ($260 psf) within the submarket over the previous 6 mos. for newer vintage product (2022 & newer).  Upon delivery, Skyway Towns will represent the first & only BTR community of institutional quality & scale in Seminole County, home to the No. 1 rated public school district in state of Florida, and the Orlando region’s largest suburban white-collar employment center…

 

This will likely be a quicker process with offers due towards the end of January.

 

Key summary points below…

The Product:

84-unit, luxury BTR community by Toll Brothers® (NYSE: TOL) featuring two-story, concrete-constructed townhome units averaging 1,720 SF across two distinct 3BR x 2.5BA floorplans
9’4 first floor ceiling heights
All homes feature attached garages (38% two-car / 62% one-car garages), luxury finishes & smart home technology
Community features include a dedicated amenity footprint with a swimming pool, sundeck, and cabana house with covered patio & restrooms
 

The Location:

Skyway Towns is located adjacent (walkable) to the Galileo K-8 School (‘A’ rated), a top public charter school in the Orlando MSA
Lake Mary / Sanford (10.1mm sf office) is Orlando’s largest suburban white-collar employment hub with major employers including AAA (world HQ),  BNY Mellon (recent 300K-SF expansion), Verizon (corporate finance HQ), Deloitte (recently expanded), and JPMorgan Chase, among others
Property is conveniently situated off Lake Mary Blvd, 5 minutes east of the 417 Beltway, enabling seamless commutes to each of north Orlando’s major employment centers within 20 minutes, including: University of Central Florida (No. 2 largest public university in U.S. with 70K students, 13K+ employees), Siemens Energy Americas HQ (5K+ employees), Central Florida Research Park (largest research park in state of FL, 10K+ employees), and Maitland Center Offices (7.8mm sf office)
 

The Opportunity:

As a forward sale, the plan here is for a buyer to close on homes in several tranches as they’re CO’d / completed, based on a pre-determined takedown schedule. Initial tranche deliveries are scheduled for July 2025, projected to deliver at a pace of 18 units per quarter, with anticipated final completion of the community in July 2026
Closings will be subject to each home being completed per plans & specs, and receipt of certificates of occupancy',FALSE,TRUE,''),
('Sunshine Trio BTR Portfolio','6 - Passed','Orlando, FL',358,2025,377094,135000000,'2025-01-23','2024-12-11','2025-01-27','All Docs Saved - We’re wrapping up the OM & materials now, plan is to launch the first week of the New Year.  Will be a fairly quick process with CFO likely late January timeframe.

 

We’re targeting the $135 million range (± $375K per unit) for the portfolio, which blends to a lower 6s un-trended yield.  

 

Nona West (Orlando): ± $80MM range (high 5s to low 6s un-trended)
Oasis at Longwood (Sarasota): Low/mid $30MMs range ( high 5s to low 6s un-trended)
Gardenside (Ormond Beach): Low/mid $20MMs range (mid 6s un-trended)
 

Keep us posted with any questions in the interim.',FALSE,TRUE,''),
('The District','6 - Passed','Charlotte-Gastonia-Rock Hill, NC-SC',287,2012,222996,64000000,'2024-08-28','2024-07-25','2025-01-24','All docs saved  - Pricing: $64M, which equates to a day 1 cap rate of 5.25%, with value-add upside via unit renovations to push IRR north of 20%. In-place assumable debt is at a 4.56% fixed rate (with IO remaining – see below).

 

Financing: Offered two ways:

The asset has accretive assumable debt. See page 10 of OM. At guidance, LTV is 60%, with 2.5 years of IO at 4.56% fixed Fannie (inclusive of supplemental loan).
Free & clear debt quote is in our doc center. At guidance, LTV is 60-63% with 2-5 year IO periods, depending on the product, buy-downs, etc.. This deal is “Mission Rich” with 88% Mission Driven Business at 80% of AMI so this should qualify for 35-year amortization.
 

Timing: Offers will be reviewed as received. Offers due no later than end of day Thursday, August 22.

 

Tours: Available by request with at least 24 hour notice.',TRUE,TRUE,''),
('The Marino Apartments','6 - Passed','West Palm Beach-Boca Raton, FL',359,1987,314763,113000000,NULL,'2025-01-10','2025-01-21','All Docs saved - Guidance is $113M which is a 5% cap in place.  It’s a value-add deal (45% of units remaining to be renovated), with a ~100 bps of renovation premium (5% going in cap, and a 6%+ cap post-renovations). 

The OM should be live mid this week.    Let us know when you’d like to tour, or when you want to jump on a call to discuss in more detail',TRUE,TRUE,''),
('Onyx on First','6 - Passed','Washington, DC-MD-VA',266,2008,178571,47500000,'2025-01-15','2024-12-18','2025-01-14','Loan Sale',TRUE,TRUE,''),
('Coral Palms Apartments','6 - Passed','Naples, FL',288,1987,236111,68000000,'2025-01-14','2024-12-09','2025-01-09','Coral Palms = 68M, 
Oasis = 59M
Notes:
LE Miller is seller
Strong trade outs 10-12%
Coral Palm was LIHTC until recently and is being re-tenanted
Mid January CFO',TRUE,TRUE,''),
('Oasis Naples Apartments','6 - Passed','Naples, FL',216,1992,273148,59000000,'2025-01-14','2024-12-09','2025-01-09','Coral Palms = 68M, 
Oasis = 59M
Notes:
LE Miller is seller
Strong trade outs 10-12%
Coral Palm was LIHTC until recently and is being re-tenanted
Mid January CFO',TRUE,TRUE,'')
ON CONFLICT (name) DO NOTHING;

INSERT INTO deals (name,status,market,units,year_built,price_per_unit,purchase_price,bid_due_date,added,modified,comments,flagged,hot,broker) VALUES
('Avra & Cirro at CenterWest','6 - Passed','Baltimore, MD',262,2020,286259,75000000,NULL,'2024-12-17','2025-01-09','We are guiding $75M- let us know if we should connect by phone to discus in greater detail.',TRUE,TRUE,''),
('ARIUM Peachtree Creek','6 - Passed','Atlanta, GA',340,2004,194117,66000000,'2024-09-17','2024-09-04','2025-01-03','All Docs Saved - Appreciate your interest. CFO will be Tuesday, September 17th.

Pricing is $66M ($194K/Unit) which is 5.65% cap in-place with stabilized economic losses, and a 6.32% cap in year 1 through operational and value-add upside.

Built in 2004 by Worthing Companies, ARIUM Peachtree Creek offers investors the unique opportunity to execute a value-add strategy with interior and amenity upgrades to achieve rental premiums and income growth.

The property provides residents with convenient access to 500K+ jobs within Atlanta’s major employment nodes, including Executive Park Medical District, Buckhead, Perimeter Center/Pill Hill, Midtown and Downtown.

When are you available to discuss or get through for at tour?',TRUE,TRUE,''),
('Moda North Bay Village Apartments','6 - Passed','Miami, FL',285,2015,315789,90000000,'2025-01-21','2024-11-21','2025-01-02','All Docs Saved - Jay…target on this is $90mn. Thanks.',TRUE,TRUE,''),
('Triumph Phase 2','6 - Passed','',79,2025,300000,23700000,'2025-01-15','2024-12-10','2025-01-02','All Docs Saved - Guidance on Triumph Phase II is $290-$300K PU ($152-157 PSF) which equates to a stabilized cap rate of ~7.0% after leasing is complete and concessions are burned off. Triumph Phase II offers the opportunity to acquire a 79-unit community to be built by DR Horton on a forward basis in the nation’s fastest growing MSA with first deliveries set for June 2025.
The Property will consist of individually-platted, large and efficiently designed 3-, 4-, and 5-bedroom floor plans (1,900 SF on average), all offering 2-car garages, private fenced yards, luxuriously appointed interiors, and concrete block construction. The Property benefits from its location within The Villages MSA, which ranks as the fastest-growing metro area in the United States. The affluent community boasts high average household incomes of $107,488 within 1-mile and convenient access to I-75 and the Florida Turnpike which provides residents with easy access to major employment hubs in Tampa and Orlando.
Some additional investment highlights include:
•	Significant Discount to Retail Home Values which average ~$370,000 within 5-miles
•	Nation-Leading Population Growth, with 40%+ 5 Year Population Growth Projected Within 1-mile
•	Immediate Access to Prime Retail and Medical including Trailwinds Village and UF Health The Villages
•	Central Location with Connectivity to Major Employers via I-75 and the Florida Turnpike
Let me know if you want to hop on a call to discuss.',FALSE,TRUE,''),
('The Parian Mooresville Apartments','6 - Passed','',230,2023,273913,63000000,NULL,'2024-09-23','2024-12-16','All Docs Saved - This one is off market so please keep it confidential. The developer/seller is Davis Development. 
 
The bogey is +/- $63M, $275k per unit.  About a month ago we had a HNW family office offer $62M ($270k per unit) and Davis countered with $64M ($278k PU). That HNW family office subsequently tied up a deal in Orlando and has not re-engaged on Parian. 
 Very strong demos and there is an abundance of nearby retail and jobs – Lowes’ corporate HQ (6,000 employees) is less than 10 minutes away. 
 
You asked specifically about supply – the pipeline is attached (map).  The punchline is that there are ~700 conventional units in lease-up and only 1 deal under construction if you cast a very wide net across the submarket.  As noted below, there are real barriers to entry via suburban infrastructure constraints in a high growth market and entrenched NIMBY’ism.  
 
A couple additional data points as you dig in:
•	The most recent suburban Charlotte comp is the Woodfield deal Lakehouse on Wylie which is set to close at $298K per unit to DWS.
•	Mooresville recently ranked #1 Fastest Growing Suburb in the Country (Mooresville Fastest Growing Suburb Article)
•	High barrier to entry submarket: Developer sues town of Mooresville claiming de facto moratorium            
o	The UDO was recently amended to require conditional rezonings even if a site is by right MF. The submarket has seen NIMBYism skyrocket in recent years due to rapid growth. 
•	Two high profile recent jobs announcements in Mooresville:
o	Dehn to create USA HQ in Mooresville with 200+ jobs: https://www.bizjournals.com/charlotte/news/2024/01/24/dehn-se-mooresville-iredell-new-jobs-investment.html
o	Corvid Technologies wins approval for $30M HQ: https://www.bizjournals.com/charlotte/news/2024/01/17/corvid-technologies-mooresville-lake-norman-hq.html
•	In early September, Charlotte City Council approved the project and funding proposal for the Red Line extension.  Still some hoops to clear, but City Council approval was a big hurdle to clear in its approval process.  (City Council Approves Red Line Article)',TRUE,TRUE,''),
('The MID Apartment Residences','6 - Passed','West Palm Beach-Boca Raton, FL',230,2021,304347,70000000,NULL,'2024-11-21','2024-12-16','All Docs Saved - 70mm….offer when ready.',TRUE,TRUE,''),
('2116 Chestnut Apartments','6 - Passed','Philadelphia, PA-NJ',321,2013,451713,145000000,NULL,'2024-12-10','2024-12-16','All Docs Saved - JLL’s pricing guidance for 2116 Chestnut is in the mid-to-upper $140M range ($440k/unit – resi allocation), which is a 5.5% cap in-place that stabilizes at a 6.5% cap post-renovation and loss to lease recapture.

 

2116 Chestnut represents the opportunity to acquire an iconic 2013 vintage, 321-unit high-rise featuring 8,171 square feet of 100% leased commercial space and a 130-space parking garage. As currently positioned, the asset features 286 unrenovated, 13 partially renovated, and 22 fully renovated apartment homes. The partial and full renovation are achieving average premiums of $165 and $313. Furthermore, the October lease trade-out outlines consistent organic rent growth, evidenced by new leases and renewals increasing 4.2% and 4.1%, respectively over the trailing 12 months.

 

The Property’s unmatched location benefits from its affluent resident demographic, boasting an average household income above $250k. Notably, 2116 Chestnut is a magnet for young professionals, students, and families alike. It attracts those working and studying at CHOP, UPenn, and Wharton, all within a 1.5-mile radius. The neighborhood also offers prestigious private schools, upscale retail, and a thriving culinary scene.',TRUE,TRUE,''),
('Harper Grove Apartments','6 - Passed','Lakeland-Winter Haven, FL',264,2023,NULL,NULL,NULL,'2024-12-09','2024-12-16','Under contract to Beacon, scheduled closing for 1/15/25

Research, ZRS managed deal',FALSE,TRUE,''),
('The Retreat at Sunset Walk Apartments','6 - Passed','Orlando, FL',352,2023,250000,88000000,NULL,'2024-11-27','2024-12-10','All Docs Saved - TBD but $250K+ per door. Let us know where you shake out to on value.',TRUE,TRUE,''),
('Arbor Crest of Silver Spring (Senior 62+)','6 - Passed','Washington, DC-MD-VA',80,2004,187500,15000000,NULL,'2024-11-20','2024-12-10','All Docs Saved - $15m. Pretty attractive basis ($187kpu)',TRUE,TRUE,''),
('Cabana Bridges','6 - Passed','Tucson, AZ',288,2023,NULL,NULL,NULL,'2024-12-04','2024-12-10','All Docs Saved -',TRUE,TRUE,''),
('The Point at Monroe Place','6 - Passed','Washington, DC-MD-VA',202,2008,346534,70000000,'2024-11-12','2024-10-03','2024-12-10','All Docs Saved - "Guidance is in the low $70M range."',TRUE,TRUE,''),
('The Stratford','6 - Passed','Miami, FL',244,1992,315573,77000000,'2024-11-21','2024-10-28','2024-12-10','All Docs Saved - Target price is $315k per unit, 5.25 cap.  Great location in the Kendall submarket.  About half the property can still be fully rehabbed for a $350 premium.  In addition, there are several other upgrades available to the amenities, exteriors and partially renovated units.  Would you like to arrange a time to discuss or set up a tour?',TRUE,TRUE,''),
('Park 2300 Apartments','6 - Passed','Charlotte-Gastonia-Rock Hill, NC-SC',384,1989,190104,73000000,'2024-11-12','2024-10-07','2024-12-10','All Docs Saved - Guidance is low $190s/u, which is a 5.65% in-place cap (tax and insurance adjusted).

 not a lot of supply here - JS

We’ve received strong early interest given that there have only been four value-add properties built in the 80s to trade this year in Charlotte; only one of those properties provided scale above 300 units.

 

We will relaunch with the OM and UW materials this week and then likely call for offers early-to-mid November.

 

Let us know if you would like to discuss further or schedule a time to see the property.',TRUE,TRUE,''),
('The Point at Herndon','6 - Passed','Washington, DC-MD-VA',244,2004,356557,87000000,'2024-11-12','2024-05-09','2024-12-10','All Docs Saved

--

off mkt from Berkadia (we can get first look)

Berkadia’s BOV is 150 mil combined, not sure how it allocates per deal. id guess ridgeline is going to have higher rents and be more expensive given the construction quality

Nice quality deals, and per Crivella they are blank slate value-add opportunities

Update 10/2/24 - CBRE
Hitting the market today…

$355kpu to $365kpu. FYI - Brian Margerum',TRUE,TRUE,''),
('Forma At The Park','6 - Passed','Dallas-Fort Worth, TX',166,1965,224698,37300000,NULL,'2024-11-19','2024-12-10','All Docs Saved - Jay,

The whisper is $37.3 million, a 6% cap. The offering includes the assumption of an existing Freddie Mac loan at 71%+ leverage at 4.64% fixed interest with I/O remaining.   Great positive leverage and cash-on-cash going in.  Please call to discuss further or set up a tour.

 

Link: Forma at the Park Offering

 

Highlights:

166 Units in Kessler Park Neighborhood of Dallas, TX
Assumable Freddie Mac Loan
10 Year Term Maturing 10/1/32 (8 Years Remaining)
5 Years Interest Only Expiring 10/1/27 (3 Years Remaining)
$26,625,000 Principal Balance
4.64% Interest Rate
Excellent Cash on Cash Returns Going-In:  7%+ Cash on Cash Returns.  High rents ($1,900 Avg) with stable occupancy along with the low interest interest-only debt service generates above-market cash returns day 1
Irreplaceable, Prestigious Kessler Park Neighborhood Adjacent to Golf Course: The long-time established Kessler Park neighborhood near Downtown Dallas with homes over $1 million and the accompanying golf course offer a location advantage that will provide long-term value appreciation.
Expense reductions in process: Expense reductions Included a drop in the insurance quote by $350/unit/year and anticipated reduction in utilities for 2025.
Near Downtown Dallas and Extensive Lifestyle Amenities: Closely Proximate to Downtown Dallas, Sylvan Thirty, Methodist Hospital, Trinity Groves, Bishop Arts, among many other destinations
Very Large, Renovated Units Including Townhomes: Forma offers large apartments averaging 1,153 SF. All units (except 4) have been substantially renovated including the addition of washer/dryer conntects.
Tremendous Value-Add Potential Including:
Additional Premium upgrades including hard surface countertops and other high-level finishes
Common area upgrades including landscaping updates, new pool furniture, additional balcony and façade renovations, etc.
Adding W/D Machines in remaining units (most already have machines) 
New windows in additional units
Phenomenal Rent Growth: In 2024 the property has averaged about 4% growth on renewals.  Plus, over the last 24 months, the property has experienced extremely strong rent growth of 13%, supporting the economics of further value-add.',TRUE,FALSE,''),
('District at 54','6 - Passed','Raleigh-Durham-Chapel Hill, NC',330,2023,235000,77550000,'2024-11-13','2024-10-22','2024-12-10','All Docs Saved - Guiding to $235k/unit here 

5-5.25 cap depending on tax appeal - JS

Let me know if it makes sense to jump on a call to discuss story further here',TRUE,TRUE,''),
('The Flats Baltimore','6 - Passed','Baltimore, MD',152,2015,217105,33000000,'2024-12-05','2024-11-21','2024-12-10','All Docs Saved - Guiding to $72-74m which breaks down to $32-34m for 2 East Wells and $40-42m for 1901 that equates to a great price per unit at $208-214k/unit.  These properties feel like a core plus opportunity with their age (2012 and 2015) but have the potential to push value even more with a light value-add upgrade on interiors and common area.  The neighborhood this sits in is the hottest one in Baltimore with the Under Armor corporate campus already substantially complete located walking distance from this location.  There is a pipeline of newly delivering Class AA with rents $450+ more per month and cost of $350+k/unit, making this basis feel great.  
 
While it can be purchased all cash, it does have existing HUD debt at 2.68% and a LTV in the low 60 percent range.  Cap rate on trailing is mid-upper 5s and first year over a 6 which equates to a mid-teens IRR if you do nothing but grow rents and upper teens IRR if you layer in light value-add.  Average cash-on-cash is 10%.  It’s in year 1 of the triennial so the taxes are fixed for the next 2 years.  
 
I’ll be touring the property later this week.  CFO hasn’t been set yet but will likely be Dec 5th .
 
Here is the link:  The Flats & The Lofts 
  
Welcome your thoughts and interest, 
Drew
 
This is a rendering of the area that is being fully developed now and is over halfway complete:',TRUE,TRUE,''),
('The Lofts Baltimore','6 - Passed','Baltimore, MD',193,2012,212435,41000000,'2024-12-05','2024-11-21','2024-12-10','All Docs Saved - Guiding to $72-74m which breaks down to $32-34m for 2 East Wells and $40-42m for 1901 that equates to a great price per unit at $208-214k/unit.  These properties feel like a core plus opportunity with their age (2012 and 2015) but have the potential to push value even more with a light value-add upgrade on interiors and common area.  The neighborhood this sits in is the hottest one in Baltimore with the Under Armor corporate campus already substantially complete located walking distance from this location.  There is a pipeline of newly delivering Class AA with rents $450+ more per month and cost of $350+k/unit, making this basis feel great.  
 
While it can be purchased all cash, it does have existing HUD debt at 2.68% and a LTV in the low 60 percent range.  Cap rate on trailing is mid-upper 5s and first year over a 6 which equates to a mid-teens IRR if you do nothing but grow rents and upper teens IRR if you layer in light value-add.  Average cash-on-cash is 10%.  It’s in year 1 of the triennial so the taxes are fixed for the next 2 years.  
 
I’ll be touring the property later this week.  CFO hasn’t been set yet but will likely be Dec 5th .
 
Here is the link:  The Flats & The Lofts 
  
Welcome your thoughts and interest, 
Drew
 
This is a rendering of the area that is being fully developed now and is over halfway complete',TRUE,TRUE,''),
('Magnolia View Apartments','6 - Passed','Dallas-Fort Worth, TX',180,2009,183333,33000000,'2024-12-11','2024-11-19','2024-12-10','All Docs Saved - We anticipate Magnolia View will trade in the $33M-$34M range ($183k-$188k per unit). This 180-unit property, built in 2009, is located in Midlothian, TX just 30 minutes from both Dallas and Fort Worth via US High 287 or US Hwy 67.

 

The property has an ideal unit mix which includes 67% two- and three-bedroom units, with 40 direct access garages and 80 in-line garages. New ownership will have the opportunity to add value by implementing stainless steel appliances, granite/quartz countertops etc on 100% of the units.

 

Midlothian is a growing suburb of DFW with a median house income of more than $120k and a top-rated school district – Midlothian ISD. Major employers in the area include Baylor Scott & White Medical Center, Gerdau steel manufacturer, and a large Target distribution center.

 

The call for offers date will be December 11th. Please let us know if you have any questions or would like to schedule a tour.',TRUE,TRUE,''),
('The Collection at Scotland Heights','6 - Passed','Washington, DC-MD-VA',74,2023,459459,34000000,'2024-12-03','2024-11-21','2024-12-10','All Docs Saved - Around $34mm.  They have 83% retention and getting 7% pops on renewals.

 

Interesting (maybe useful) stats from recent NAR report:

 

1st time home buyers

In the last year represented 24% of total sales, AN ALL TIME LOW. Last year was 32% and prior to 2008 it was typically around 40%.
Median HHI was $97k (huge number and US avg is around $80k)
Median HH Age 38
 

All buyers

56 yrs old up from 49 last year
62% married, 20% single female, 8% single male
73% recent buyers did not have a child under 18 in the home…highest ever
LOCATION 16% in urban/central city highest in 10years
 

All sellers

63 yrs old highest ever recorded
23% was desire to move closer to friends (probably snowbirds, etc.)
100% of asking price, highest recorded since 2002',TRUE,FALSE,''),
('Casa Bella on Westshore','6 - Passed','Tampa-St. Petersburg-Clearwater, FL',250,2007,294000,73500000,'2024-12-05','2024-10-30','2024-12-10','All Docs Saved - Thanks for reaching out. Pricing guidance is $73.5MM and we have set the call for offers date for 12/5.

 

Would you like to schedule a tour?

 

We’re also marketing Maeva in Lutz / Wesley Chapel if you would like to tour that one as well.',TRUE,TRUE,''),
('Serenza Apartments','6 - Passed','Orlando, FL',320,2024,NULL,NULL,NULL,'2024-11-27','2024-12-02','All Docs Saved',TRUE,TRUE,''),
('Avila','6 - Passed','Orlando, FL',269,2022,NULL,NULL,NULL,'2024-11-11','2024-11-11','Signed CA, Cap Rate Research for Park Place Oviedo, Under Contract as of 11/11/24',FALSE,TRUE,''),
('Mezzo Desert Ridge - Development','6 - Passed','Phoenix-Mesa, AZ',174,NULL,NULL,NULL,NULL,'2024-09-24','2024-11-07','',FALSE,TRUE,''),
('2116 Kalorama','6 - Passed','Washington, DC-MD-VA',28,2025,535714,15000000,NULL,'2024-10-22','2024-11-07','All Docs Saved -',FALSE,TRUE,''),
('Towns at Andrews Park','6 - Passed','Washington, DC-MD-VA',59,2023,423728,25000000,NULL,'2024-10-22','2024-11-07','All Docs Saved - $25m – mid 6% Cap.
Are you guys looking at BTR? Happy to connect on this.',TRUE,TRUE,''),
('Astoria at Celebration','6 - Passed','Orlando, FL',306,2015,281045,86000000,NULL,'2024-10-30','2024-11-07','All Docs Saved - Jay,

Any trips to Orlando for the holidays?  Hope all is well.  2015 vintage product in a super affluent location. Whisper price in the $280,000s/unit range ($86-$89MM). Few highlights below:
 
•	Can be bought free & clear or with assumable debt fixed at 4.25% with 4.5 years left
•	Over 97% occupied; leased rents north of $2010/month
•	NOT on revenue management, so feels like there’s room to increase rents
•	Walking distance to new high-end Celebration Pointe with Publix and great restaurants
•	Avg HH income of $128,000 (1 mile)
•	Over 106,000 cars per day drive by visibility
•	Really nice looking deal with stellar amenity footprint and great floor plans',TRUE,TRUE,''),
('Hampton Edison - Homes for Rent','6 - Passed','Phoenix-Mesa, AZ',151,2024,228476,34500000,'2024-11-14','2024-10-24','2024-11-07','All Docs Saved - Thank you for your interest in Hampton Edison, 151-unit, luxury-built, Build-to-Rent Community in Maricopa, AZ. (CA: Deal Room link). Hampton Edison is a premier opportunity to acquire a new construction asset in the 5th fastest growing city in the nation according to the US Census Bureau.  More info on the offering below.
 
•	Guidance: $34,500,000 or $228,477/unit  
•	Stabilized Pro Forma Cap Rate: 7.17%  
•	Occupancy: 25% Occupied; 26% Leased
•	Tours: Please reach out to Hannah Olson to schedule onsite tours
•	Financing: Please reach out to Brandon Harrington and Bryan Mummaw to discuss financing options 
•	Call for Offers: To be announced 
 
Deal Highlights
Luxury-Built, Build-to-Rent Community with Advanced HercuWall Technology located in the 5th Fastest-Growing City in the Nation 
 
•	151-unit, luxury-built, BTR community that is steps away from the most prominent retail corridor in Maricopa, within minutes of a new Sprout’s Farmers Market anchored center with dozens of big box chains and local retailers 
•	Adjacent to Cold Beers and Cheeseburgers, Marshall’s, Fry’s, Ross, Bashas’, Dutch Bros Coffee, Crumbl Cookies, Planet Fitness, Culver’s, Starbucks, Wells Fargo, Barro’s Pizza, Firehouse Subs, Chipotle, The Roost Bar & Grill, Walgreens, Ace Hardware, and more 
•	Maricopa is ranked as the 5th fastest-growing city in the nation, according to 2023 population statistics, and has seen a YoY population increase of 7.1% and a five-year population increase of 26%  
•	Pinal County leads Arizona in job growth, according to the US Bureau of Labor Statistics, it saw an increase of nearly 10,000 new jobs between 2019-2023, a 16% increase 
•	Recent single-family home sales in the neighborhood directly north of Hampton Edison sold for as much as $450,000/home
•	The asset was developed with innovative HercuWall Technology which is designed for efficient, durable, and eco-friendly construction that is R-30 insulated, weather, mold, hurricane, insect, and fire resistant as well as airtight, green, and pot-proof 
•	Hampton Edison is less than 30-minute commute to the South Chandler employment hub including Price Road Corridor, which is home to over 45,000 jobs, Intel’s Ocotillo Campus, which employs over 6,100, and Chandler Airport Business Park which employs over 13,600 
•	Maricopa offers more affordable housing alternatives which provide direct highway access to Chandler which has one of the highest concentrations of high-tech, high-wage jobs in the greater Phoenix MSA 
•	The property features direct access to the Chandler and Casa Grande employment centers via the SR 347 and Maricopa-Casa Grande Highway arteries, providing a seamless 30-minute commute to both employment centers 
•	Maricopa’s population grew by 11,833 over the last 5 years and is projected to grow by 14,354 over the next 5 years
•	Strong submarket dynamics with an average household income exceeding $102,000 coupled with the tremendous net migration statistics supports the perpetual demand for multifamily housing in the market and opportunity for substantial organic market rent growth 
 
Community Amenities: 
•	resort-style pool and spa
•	24-hour fitness center
•	pet park
•	community firepit and ramada
•	lush courtyards
•	covered outdoor kitchen 
•	gated access
•	leasing office with a resident lounge 
 
Top of Market Interiors:
•	quartz countertops with undermount kitchen sinks
•	stainless steel appliances
•	premium hardwood cabinetry
•	10’ ceilings in every home
•	wood-style flooring
•	oversized low-energy dual-paned aluminum windows
•	full size washers and dryers
•	private enclosed backyards
•	select homes with porches  
 
Location Highlights:
•	A massive business park known as Maricopa’ future Industrial Triangle, is situated on 680-acreas of the Maricopa Casa-Grande Highway, along the railroad spur, is underway and will feature a SMARTRail Park to include roughly 12-million square feet of industrial and business developments and expected to bring 18,000-36,000 new jobs to the city  
•	Located less than a mile west of Hampton Edison, PHX Surf, a world-class surf destination blended with total health and wellness will occupy 13 acres and will feature simulated surf wave pools, curated boutiques, sandy beaches, a hotel, play pools, food and beverage, and recreational amenities
•	S3 BioTech Medical Campus is a 28-acre medical campus planned in Maricopa that is set to include a 100,000 square foot ER hospital, hundreds of condominiums, a 125-150 room hotel, and an innovation campus which is expected to produce over 3,000 jobs
•	University of Arizona’s Agricultural center is moving forward with a vast Innovation Campus in Maricopa which will span across 2,100 acres and will feature a technology park, and 600-acres of mixed-use commercial developments which is expected to have a $4 billion economic output and produce tens of thousands of new jobs 
•	A ±320-acre retail, office, manufacturing, and warehouse park, Estrella Gin Business Park, is underway less than a mile west of Hampton Edison and will add approximately 300,000 square feet of office/flex/warehouse space and is expected to create 700 new jobs 
•	Murphy Park, a 500-acre master plan, located just north of Maricopa-Casa Grande Highway and the Ak-Chin boundaries is set to include 260 acres for new business and industrial developments 
 
Major Economic Drivers (all within 5-30 minutes)
•	Intel Ocotillo Campus
•	Price Road Employment Corridor 
•	Harrah’s Ak-Chin Casino 
•	Apex Motor Club
•	Lucid Motors
•	Industrial Triangle Development
•	PHX Surf Development
•	S3 Biotech Medical Campus
•	UofA Innovation Campus
•	Estrella Gin Business Park
•	Murphy Park',TRUE,TRUE,''),
('The Summit on 401','6 - Passed','Fayetteville, NC',291,2012,154639,45000000,'2024-11-20','2024-11-07','2024-11-07','All Docs Saved - Per OM first round offers 11/13/24, B&F 11/20/24

Jay – guidance here is in the $150k-$160k per door range, yielding a high-5% / low-6% cap on in-place numbers, tax-adjusted. At this guidance, the opportunity is boasting a double digit cash-on-cash and a 20%+ IRR on a 5-year hold. Do you have any time today or tomorrow for a call to discuss?',TRUE,TRUE,''),
('Royal Villas Townhomes','6 - Passed','Melbourne-Titusville-Palm Bay, FL',48,2007,229166,11000000,'2024-11-14','2024-10-31','2024-11-07','All Docs Saved - Thanks for your interest on this one! Target pricing for Royal Villas is in the low-to-mid $11MM’s / $230k+ per unit. This BTR-style community has significant value-add upside through interior renovations and stabilizes to a 7%+ Yield-on-Cost!

 

Located in the ever-growing Space Coast in Central Florida, Royal Villas is located in the heart of Titusville between I-95 and US Highway 1. Titusville has limited supply with 210 units delivered in the previous 12 months and ZERO units currently under construction.

 

Royal Villas was built in 2007 and is 90% occupied. The property offers substantial upside through systematic renovations. These renovations will push rents ~$350/unit. The uniqueness of individual parcels also leads to a property tax savings, along with multiple exit plays!

 

Website: https://mmgrea-royalvillas.com/
CA / DD Docs: https://mmgrea-royalvillas.com/login
 
Please review and let us know if you have any questions as you dig in!',TRUE,TRUE,''),
('Ablon at Harbor Village','6 - Passed','Dallas-Fort Worth, TX',375,2022,NULL,NULL,NULL,'2024-11-05','2024-11-05','',FALSE,TRUE,''),
('Sharon Pointe Apartment Homes','6 - Passed','Charlotte-Gastonia-Rock Hill, NC-SC',190,2001,178947,34000000,'2024-11-01','2024-10-09','2024-11-04','All Docs Saved - $34mm which is a 5% in place T3/T12 metrics
Loan assumption: 2.63% rate / 2 years of I/O left. 2032 maturity. 65-70% leverage.
Morgan bought it in 2020 part of 20 property portfolio so now starting to sell off individually with the compelling debt.
All exterior work ($2.5mm total spent) has been done (roofs, siding, etc). New owner can focus on interiors which are essentially all original.',TRUE,TRUE,''),
('Courtney Ridge Apartments','6 - Passed','Charlotte-Gastonia-Rock Hill, NC-SC',460,2000,228260,105000000,'2024-07-30','2024-07-01','2024-10-29','All docs saved 230/unit',TRUE,TRUE,''),
('Gateway at Cedar Brook','6 - Passed','Atlanta, GA',164,1972,182926,30000000,NULL,'2024-10-14','2024-10-24','All Docs Saved - These can be purchased together or separate.  They were built by the same developer, renovated (~$30k/unit and capex detail in deal room) at the same time and both have the same fixed rate loans that started in 2020. Both also just appealed and won 2024 tax appeals so they are frozen until 2027.  Supplementals are also available on both to bump LTVs to 60-70% (in deal room).
Super clean assets and there is a Whole Foods about 2 miles from these properties.  In addition, North Dekalb Mall (less than 1 mile from Domain) is currently being demolished to make way for a new 73-acre mixed-use development called Lulah Hills and a single family neighborhood by Toll Brothers is about to begin vertical construction across the street from Gateway’s main entrance.
Details below:
Gateway at Cedar Brook - Pricing guidance is $30M which is a ~6.25% year one cap and 10.75%+ cash on cash in year one.  
•	Asset Highlights:
o	Occupancy: 94%; Avg. Leased Rent: $1,529 ($1.34/ft).
o	The current in-place loan is offered at a 2.96% interest rate with 5 years of I/O remaining and 10 years of term remaining.
o	Gateway at Cedar Brook successfully won their 2024 tax value appeal. The taxes will be frozen through 2026.
o	Current and prior ownership have invested a combined $7M+ into CapEx upgrades.',TRUE,TRUE,''),
('Domain at Cedar Creek','6 - Passed','Atlanta, GA',168,1970,181547,30500000,NULL,'2024-10-14','2024-10-24','All Docs Saved - Domain at Cedar Creek - Pricing guidance is $30.5M which is a ~6.25% year one cap and 12.25%+ cash on cash in year one.  
•	Asset Highlights:
o	Occupancy: 94%; Avg. Leased Rent: $1,541 ($1.36/ft).
o	The current in-place loan is offered at a 2.96% interest rate with 5 years of I/O remaining and 10 years of term remaining.
o	Domain at Cedar Creek successfully won their 2024 tax value appeal. The taxes will be frozen through 2026.
o	Current and prior ownership have invested a combined $7.8M+ into CapEx upgrades',TRUE,TRUE,''),
('Town Deer Valley','6 - Passed','Phoenix-Mesa, AZ',388,2024,324742,126000000,'2024-10-17','2024-10-21','2024-10-22','Guidance is $325k per unit.',TRUE,TRUE,''),
('The Lodge at Mallard Creek Apartments','6 - Passed','Charlotte-Gastonia-Rock Hill, NC-SC',264,1999,170454,45000000,'2024-10-17','2024-09-24','2024-10-22','All Docs Saved - Part of 7 Property Portfolio 

taxes - current AV vs PP has 25bp impact on cap rate. currently under appeal. if they settle on an appeal higher than the PP before it is sold it will not be able to be re-appealed after sale. Sounds like the appeal is dragging out and they hope it can close before the appeal is finalized so it can be close to PP. from Suzanne "We''re actually on this appeal, so familiar with the property. 

The answer is that the final value for 2023 will dictate the assessment for the entire revaluation cycle (tax years 2023, 24, 25, and 26).  The next revaluation will be in 2027.  Once an appeal is fully adjudicated, you cannot appeal again in the same cycle.  However, the settlement process is dragging out with Mecklenburg County, so if the deal closes prior to the 2023 case being finalized, the hope is that the value would be close to the purchase price.  "

not far from magnolia in university submarket JS

Starwood is selling: Talked to Ian:

Dallas = low mid 70s
Tampa = low 80s
Lakeland = high 60s
Charlotte = mid 40s

Other:
-	Open to individual offers
-	SREIT is selling 19 deals nationally to free up liquidity
-	CFO likely 10/14 week
-	Cap rates ~5 (Lakeland 5.25)',TRUE,TRUE,''),
('Century Ariva','6 - Passed','Lakeland-Winter Haven, FL',312,2017,215000,67080000,'2024-10-17','2024-09-25','2024-10-22','All Docs Saved - Part of 7 Property Portfolio Starwood is selling:
Talked to Ian:

Dallas = low mid 70s
Tampa = low 80s
Lakeland = high 60s
Charlotte = mid 40s

Other:
-	Open to individual offers
-	SREIT is selling 19 deals nationally to free up liquidity
-	CFO likely 10/14 week
-	Cap rates ~5 (Lakeland 5.25)


Update from Ken at Eastdil 10/10/24:
Guidance $215k/unit for Lakeland',TRUE,TRUE,''),
('Advenir at Eagle Creek','6 - Passed','Houston, TX',258,2008,NULL,NULL,'2024-11-19','2024-10-17','2024-10-21','All Docs Saved -',TRUE,TRUE,''),
('The Wyatt at Presidio Junction Apartment Homes','6 - Passed','Fort Worth, TX',348,2009,NULL,NULL,NULL,'2024-10-16','2024-10-21','RR/T12',TRUE,TRUE,''),
('Galleries at Park Lane Apartment Homes','6 - Passed','Dallas-Fort Worth, TX',246,2017,200000,49200000,NULL,'2024-09-24','2024-10-08','All Docs Saved - Guiding to $200,000 per door.',TRUE,TRUE,''),
('Bell Pembroke Pines Apartments','6 - Passed','Fort Lauderdale-Hollywood, FL',300,2014,400000,120000000,NULL,'2024-09-26','2024-10-08','All Docs Saved - Jay…Target is $120mn. Thanks',TRUE,FALSE,''),
('222 Saratoga','6 - Passed','Baltimore, MD',84,2004,NULL,NULL,NULL,'2024-10-03','2024-10-07','All Docs Saved',TRUE,TRUE,''),
('400 North Apartments','6 - Passed','Orlando, FL',300,2019,333333,100000000,'2024-10-16','2024-09-26','2024-10-01','All Docs Saved - Pricing guidance on 400 North is $100M (~$333K per door or $324 PSF). The property was built in 2019, comprises 300-units plus 27,316 SF of ground-floor retail, and sits at 98% leased. Our location on the boarder of Winter Park on 17-92 in Maitland is one of the most highly desirable residential corridors with a high barrier to entry. We sit directly next to Publix, down the road from Winter Park village and Downtown Winter Park, and are zoned for Winter Park High School.',TRUE,TRUE,''),
('Southpoint Crossing Apartments','6 - Passed','Raleigh-Durham-Chapel Hill, NC',288,1998,194444,56000000,'2024-10-09','2024-09-12','2024-10-01','All Docs Saved - $195-200k/unit here',TRUE,TRUE,''),
('Arbor Place Apartments','6 - Passed','Atlanta, GA',298,2004,NULL,NULL,NULL,'2024-09-25','2024-10-01','All Docs Saved - No Guidance',TRUE,TRUE,''),
('Century Crosstown','6 - Passed','Tampa-St. Petersburg-Clearwater, FL',344,2013,238372,82000000,NULL,'2024-09-24','2024-10-01','All Docs Saved - Part of 7 Property Portfolio Starwood is selling: Talked to Ian:

Dallas = low mid 70s
Tampa = low 80s
Lakeland = high 60s
Charlotte = mid 40s

Other:
-	Open to individual offers
-	SREIT is selling 19 deals nationally to free up liquidity
-	CFO likely 10/14 week
-	Cap rates ~5 (Lakeland 5.25)',TRUE,FALSE,''),
('Century 380','6 - Passed','Dallas-Fort Worth, TX',416,2017,174278,72500000,NULL,'2024-09-24','2024-10-01','All Docs Saved - Part of 7 Property Portfolio Starwood is selling: Talked to Ian:

Dallas = low mid 70s
Tampa = low 80s
Lakeland = high 60s
Charlotte = mid 40s

Other:
-	Open to individual offers
-	SREIT is selling 19 deals nationally to free up liquidity
-	CFO likely 10/14 week
-	Cap rates ~5 (Lakeland 5.25)',TRUE,TRUE,''),
('Pine Groves','6 - Passed','Miami, FL',204,2020,263235,53700000,'2024-10-15','2024-09-10','2024-10-01','All Docs Saved - Jay – Good hearing from you.

 

The properties are available for individual acquisition or as a portfolio sale. Please see a brief overview of the offerings below:

 

PRICING GUIDANCE

We are guiding to $255k per unit (420) on the Portfolio – blended cap rate shakes out to a 5.45% in-place. Breakdown on property level acquisition is seen below.

 

Princeton Groves: $53M | $245k per unit | 5.45% in-place cap rate

 

Pine Groves: $53.7M | $263k per unit | 5.40% in-place cap rate

 

 

OFFERING OVERVIEW

The properties are located less than a half-mile away from each other in Princeton, FL, and total 420 units in 3-story garden-style layouts.

 

Princeton Groves, built in 2016, is composed of 216 units across 1-, 2-, and 3-bedroom floor plans and is offered well below replacement cost.
 

Pine Groves, built in 2020, is composed of 204 units and offers a unique tax savings opportunity through the Live Local Act.
 

 

Both properties have in-place renovation programs implemented by current ownership, including upgraded hard surface flooring, backsplashes, and smart tech packages. To date, current ownership has completed 103 units at Princeton Groves and 118 units at Pine Groves, leaving significant rent upside for new ownership to continue the in-place program that has achieved $100 rent premiums. Both properties are poised for significant rent growth, with impressive lease trade-outs over the past 90 days.',TRUE,TRUE,''),
('Princeton Groves','6 - Passed','Miami, FL',216,2016,245370,53000000,'2024-10-15','2024-09-10','2024-10-01','All Docs Saved - Jay – Good hearing from you.

 

The properties are available for individual acquisition or as a portfolio sale. Please see a brief overview of the offerings below:

 

PRICING GUIDANCE

We are guiding to $255k per unit (420) on the Portfolio – blended cap rate shakes out to a 5.45% in-place. Breakdown on property level acquisition is seen below.

 

Princeton Groves: $53M | $245k per unit | 5.45% in-place cap rate

 

Pine Groves: $53.7M | $263k per unit | 5.40% in-place cap rate

 

 

OFFERING OVERVIEW

The properties are located less than a half-mile away from each other in Princeton, FL, and total 420 units in 3-story garden-style layouts.

 

Princeton Groves, built in 2016, is composed of 216 units across 1-, 2-, and 3-bedroom floor plans and is offered well below replacement cost.
 

Pine Groves, built in 2020, is composed of 204 units and offers a unique tax savings opportunity through the Live Local Act.
 

 

Both properties have in-place renovation programs implemented by current ownership, including upgraded hard surface flooring, backsplashes, and smart tech packages. To date, current ownership has completed 103 units at Princeton Groves and 118 units at Pine Groves, leaving significant rent upside for new ownership to continue the in-place program that has achieved $100 rent premiums. Both properties are poised for significant rent growth, with impressive lease trade-outs over the past 90 days.',TRUE,TRUE,''),
('Grande Club Apartments','6 - Passed','Atlanta, GA',264,1999,189393,50000000,NULL,'2024-09-16','2024-09-24','All Docs Saved - Grande Club is owned by Starwood’s SREIT and our price guidance is approaching $50M or $180k/u which equates to a mid-5% cap rate on in place NOI (stabilized for occupancy)

 

A few investment highlights:

Nine foot ceiling product built in the late 90s product with all new roofs and fresh paint
86% of the units in classic condition (or lightly upgraded) with potential to upgrade and move rents over $200/month
Excellent frontage along Club Drive with a high traffic count of 27k vehicles per day
232K SF Publix-anchored shopping center with LA Fitness across the street and 8.8M SF of retail within a 2-mile radius of the property
The property has 30 units down from a 2020 fire, on track to be rebuilt back (by year-end) with quartz countertops, white shaker cabinets, plank flooring and stainless steel appliances',TRUE,TRUE,''),
('The Flats at 55Twelve','6 - Passed','Raleigh-Durham-Chapel Hill, NC',268,2001,200000,53600000,NULL,'2024-08-21','2024-09-24','All Docs Saved - $200k per unit which is a 5.65% cap on T3/T12 tax adjusted. Let us know if you have any questions.',TRUE,TRUE,''),
('The Grand at Westside Apartments','6 - Passed','Orlando, FL',336,2015,250000,84000000,'2024-10-08','2024-09-23','2024-09-24','All Docs Saved - Grand is $250k per unit, Axis West $280k  and Sands is $290k per unit.',TRUE,TRUE,''),
('The Sands at Clearwater Apartments','6 - Passed','Tampa-St. Petersburg-Clearwater, FL',240,2014,290000,69600000,'2024-10-08','2024-09-10','2024-09-24','All Docs Saved -  Grand is $250k per unit, Axis West $280k  and Sands is $290k per unit.',TRUE,FALSE,''),
('150 West','6 - Passed','',201,1999,164179,33000000,NULL,'2024-09-19','2024-09-24','All Docs Saved - Pricing guidance is $160k - $165k/door which reflects a market occupancy and bad debt adjusted low 5% cap. New ownership has the ability to renovate and push rents in line with nearby competitors, taking you to a 6.5%+ cap post-renovation. The current owner is Benefit Street Partners, who took over from GVA in May. 

 

Mooresville is a high-growth submarket with very strong submarket demographics with +$141K Average HHI, 71% White Collar-Population, and 55%+ Achieving Higher Education. Iredell County Schools are highly ranked with three “A” rated schools within 15 minutes of the property.  Lastly, Mooresville is a highly coveted submarket due to its immediate access to Lake Norman and top-tier retail within a 10-minute drive including Winslow Bay Commons (Target, TJ-Maxx, Sam’s Club), Mooresville Plantation (Harris Teeter, Publix, Starbucks), and Mooresville Consumer Square (Costco, Walmart, Belk).

 

We are finalizing our OM which will be available next week. Let us know a good time to jump on a call to discuss the backstory on the deal.',TRUE,TRUE,''),
('Jefferson Commons','6 - Passed','Lynchburg, VA',216,2010,222222,48000000,NULL,'2024-09-18','2024-09-24','Off Mkt from Scott Doyle - All Docs Saved',TRUE,FALSE,''),
('Walden At Oakwood','6 - Passed','',300,2010,210000,63000000,'2024-09-24','2024-08-20','2024-09-24','All Docs Saved - Thank you for your interest in Walden at Oakwood.  Walden is an immaculately maintained 300-unit suburban garden-style community offering an unmatched Value-Add Opportunity.  A few key points to consider:

 

2010 Vintage; Original Developer Owned
100% “Classic” Units
Value-Add Premium potential of $200+/unit
Significant Discount to Replacement Cost “Post-Renovation”
Direct Proximity to 490,000+ jobs
Walkable to Publix anchored retail center and Chik-Fil-A
 

Pricing for Walden at Oakridge will likely be in the low $210ks / door, which translates to a +/- 5.25% Cap. 

 

Website with Dataroom/Offering Memorandum Access:  Walden at Oakwood Dataroom

 

We are currently scheduling tours, are you available to tour this week or next?  Just let us know what works for you and we will do our best to accommodate.

 

We look forward to discussing.',TRUE,TRUE,''),
('Smith & Rio','6 - Passed','',310,2023,354838,110000000,NULL,'2024-09-10','2024-09-24','All Docs Saved - Jay – guidance is $110M which is a stabilized 5.5% cap rate.',TRUE,TRUE,''),
('Bridges at Kendall Place','6 - Passed','Miami, FL',228,2013,328947,75000000,'2024-09-18','2024-08-20','2024-09-23','All Docs Saved - Investment Highlights:
High Barrier to Entry Location (1 of 3 Deals to deliver in the submarket in last 30 Years)
+$300 discount to new construction rents (delivering 4Q24/1Q25)
First-Generation Value Add Opportunity
Highly sought after school district and adjacent to preferred charter school (Pinecrest Elementary)
Guidance:
High 70s million (low of $300s PSF)
+/- 5.00% T3/T12 (Tax/Insurance Adj.) Cap Rate
+/- 5.25% T3/T12 (Adjusted for 95% occupancy and MTM on 10 Aff. Units)',TRUE,TRUE,''),
('The Isles','6 - Passed','Fort Lauderdale-Hollywood, FL',127,2008,401574,51000000,'2024-10-09','2024-09-09','2024-09-23','All Docs Saved - All good here, hope the same for you.

 

Guidance on the Isles is around $51 million, which works out to a 5% cap, or north of a 6% cap with the core+ upside fully baked in.

 

With an average unit size of 1,421 SF, pricing works out to around $285 PSF – well below replacement cost for townhome product located 15 minutes from Downtown Fort Lauderdale.

 

Let us know if you’d like to jump on a call to discuss further or arrange a tour.',TRUE,TRUE,''),
('Eagle Rock Apartments at Columbia','6 - Passed','Baltimore, MD',184,1984,NULL,NULL,NULL,'2024-04-08','2024-09-18','',TRUE,TRUE,''),
('Maizon Bethesda','6 - Passed','Washington, DC-MD-VA',229,2021,480349,110000000,'2024-10-03','2024-08-26','2024-09-18','All Docs Saved - We''re looking for $110mm++ which is $480k/unit, about a 5% cap on inplace and a mid to high 5s on year 1 (all RE tax adjusted).  

Can you guys buy from your cousin''s over at ZOM?',TRUE,TRUE,''),
('Rialto Apartments','6 - Passed','Washington, DC-MD-VA',74,2022,270270,20000000,NULL,'2023-12-12','2024-09-17','off mkt from Chris Love',TRUE,TRUE,''),
('The Griff Apartments','6 - Passed','Nashville, TN',255,2019,307000,78285000,'2024-09-18','2024-08-15','2024-09-17','All Docs Saved - High $70 million ($305k-$310k/door)
+/- 4.50% T3/T12 (95% Occupancy/Tax/Insurance Adj.) Cap Rate (Franchise tax below line = 10 bps)
7%+ Day 1 Cash on Cash',TRUE,TRUE,''),
('SKYE of Turtle Creek Apartments','6 - Passed','Dallas-Fort Worth, TX',331,1998,300000,99300000,'2024-09-24','2024-08-14','2024-09-17','All Docs Saved - Guidance is $300k/unit which is roughly $250 PSF, so a really big discount to replacement cost. Blackrock owns on behalf of Calstrs. GID and Clarion before them. The last units were rehabbed here in 2018-2019 and are not nearly to the level that would be done today so you can definitely renovate the units and update a portion of the common areas. Let me know if you have any additional questions or would like to schedule a tour.',TRUE,TRUE,''),
('The Watch on Shem Creek','6 - Passed','Charleston-North Charleston, SC',232,1987,271551,63000000,'2024-09-26','2024-08-29','2024-09-17','All Docs Saved - Some reno''s in 2002. $63M here / ~$270K per unit

5.25% in-place, tax adjusted',TRUE,TRUE,''),
('Bass Lofts Apartments','6 - Passed','Atlanta, GA',133,1998,263157,35000000,'2024-10-01','2024-09-04','2024-09-17','All Docs Saved - This is truly a one-of-a-kind deal! It was originally a high school w/ gymnasium that was converted into lofts apartments in 1998. Price guidance is approaching $260k/u (mid-$30M+/-), which is a 5.5% in-place, adjusted cap rate.

 

Little Five Points neighborhood (1/2 mile from Eastside Beltline) – eclectic shops, restaurants, etc.
133 unique units that preserve some of the original features like the classroom doors, chalkboards, gym floor, and auditorium stage
Value-add opportunity to renovate 32% of the units and zoned to build 18 new TH on site
Sticky residents – avg. lease duration is 3+ years; no bad debt
The only existing MF in Little Five Points – no construction underway within ½ mile
Great walkability and access to parks
Option to assume current amortizing loan (see data site for more details)
 

We are also launching 841 Memorial (5 minutes away) for the same seller. This is a boutique, 80-unit property built in 2016 directly on Memorial Drive and the Eastside Beltline.

 

Price guidance is mid-to-upper $220k/unit ($18M+).
Accretive assumable loan with 4.00% rate',TRUE,TRUE,''),
('Sea Glass Apartments','6 - Passed','Fort Walton Beach, FL',288,2017,267361,77000000,'2024-10-08','2024-09-16','2024-09-17','All Docs Saved - 77MM, mid  5% cap going on insurance and tax adjusted NOI with positive leverage.',TRUE,TRUE,''),
('2929 Wycliff','6 - Passed','Dallas-Fort Worth, TX',284,2007,NULL,NULL,NULL,'2024-07-24','2024-09-16','All Docs saved - Under Contract',TRUE,TRUE,''),
('The Van Buren','6 - Passed','Washington, DC-MD-VA',51,1955,298039,15200000,NULL,'2024-08-07','2024-09-13','All Docs Saved',TRUE,TRUE,''),
('The Luzon','6 - Passed','Washington, DC-MD-VA',67,1942,200000,13400000,NULL,'2024-08-07','2024-09-13','All Docs Saved',TRUE,TRUE,''),
('R P Stellar Embassy House','6 - Passed','New York, NY-NJ',243,1961,658436,160000000,NULL,'2024-09-04','2024-09-13','All Docs Saved - We are guiding to $160M/$650K p/u which is a 5.5% cap rate and positive leverage day one.

 

Let us know if you would like to set up a time to discuss.',TRUE,TRUE,''),
('Amberleigh','6 - Passed','Washington, DC-MD-VA',752,1968,265957,200000000,NULL,'2024-09-03','2024-09-13','All Docs Saved - Gentlemen, flagging this opportunity as we’ve received reports of people not receiving the “Coming Soon” email.
Guidance is $200M, representing a 5.5% yr1 cap, 14.5% LIRR, with 13%+ rent growth on new leases and 5%+ on renewals.  Current occupancy stands at 96% and ground lease is 12.5% of EGI. Lastly, great value-add upside with 66% of the unit being completely unrenovated.

 Materials will be available for you by Thursday.  Let’s schedule a call early next week to discuss in more detail.',TRUE,TRUE,''),
('Brightwood Forest Apartments','6 - Passed','Washington, DC-MD-VA',90,1990,222222,20000000,NULL,'2024-08-29','2024-09-13','All Docs Saved - We are guiding to just under $240K per unit, allocating $210M to Dale and $20M+ to Brightwood, solving for a 5.40% in-place T3/T12 RE tax adjusted cap rate and a stabilized yield north of a 6.5% by continuing or improving upon the existing value-add program. Note all of the units offer in-unit value add upside.  Currently seller is averaging $200+ premiums for the following work, upgraded lighting, new cabinet fronts/pulls, granite counter tops, new black appliances, and upgraded kitchen/bathroom fixtures (not doing stainless or flooring).  If helpful there is assumable debt that is full term IO expiring in 2028, our team is sizing the supplemental but new debt is very attractive.',TRUE,TRUE,''),
('Dale Forest Apartments','6 - Passed','Washington, DC-MD-VA',873,1976,240549,210000000,NULL,'2024-08-29','2024-09-13','All Docs Saved - We are guiding to just under $240K per unit, allocating $210M to Dale and $20M+ to Brightwood, solving for a 5.40% in-place T3/T12 RE tax adjusted cap rate and a stabilized yield north of a 6.5% by continuing or improving upon the existing value-add program. Note all of the units offer in-unit value add upside.  Currently seller is averaging $200+ premiums for the following work, upgraded lighting, new cabinet fronts/pulls, granite counter tops, new black appliances, and upgraded kitchen/bathroom fixtures (not doing stainless or flooring).  If helpful there is assumable debt that is full term IO expiring in 2028, our team is sizing the supplemental but new debt is very attractive.',TRUE,TRUE,''),
('Elan Denton','6 - Passed','Dallas-Fort Worth, TX',300,2021,220000,66000000,'2024-09-25','2024-08-07','2024-09-13','All Docs Saved - Pricing guidance is $220k - $225k/unit. Let us know if you have any additional questions.',TRUE,TRUE,''),
('Anthem Clearwater','6 - Passed','Tampa-St. Petersburg-Clearwater, FL',416,1975,NULL,NULL,'2024-09-25','2024-09-11','2024-09-11','',FALSE,TRUE,''),
('ARIUM Sunrise','6 - Passed','Fort Lauderdale-Hollywood, FL',400,1998,312500,125000000,'2024-09-24','2024-08-22','2024-09-10','All Docs Saved - Jay…target on this is $125mn. Thanks.',TRUE,TRUE,''),
('AMLI Las Colinas','6 - Passed','Dallas-Fort Worth, TX',341,2006,260000,88660000,'2024-09-10','2024-08-07','2024-09-10','All Docs Saved - Thanks for reaching out!  Whisper price is $260K per unit.  Value add in 2 ways – unit upgrades and reduction in DCURD (improvement district) in 2028.  Happy to schedule a call to discuss further.',TRUE,TRUE,''),
('Mercury NoDa','6 - Passed','Charlotte-Gastonia-Rock Hill, NC-SC',241,2016,278008,67000000,'2024-09-11','2024-08-08','2024-09-10','All Docs Saved - We’re guiding ~$67M ($270’s per unit) which is just inside of a 5% cap.

 

The attached excel doc breaks down existing operations and highlights a path to a high 5% to 6% cap rate through an interior value-add.

 

As public parking revenue returns to 2022/early 2023 levels (gate went down in July 2023 and they recently implemented Parkwhiz) you’re at a 5% cap, and by replacing the existing bulk cable agreement you’re north of a 5% cap rate organically.

 

The full OM will be available next week and offers will be due in early September. Let us know if you have any questions as you dig in or would like to schedule a tour. Here are the high-level details of the opportunity:

 

Stable In-Place Operations: This asset has not offered concessions while maintaining ~95% occupancy and flat lease trade outs with little to no bad debt. Operations have remained resilient in the face of new supply due to the prime location and rents are poised to increase as new deliveries abate.
Upside: Strong operational performance and good bones (built by Woodfield Development in 2016) provide a great foundation for a value-add play. Current ownership has maintained the asset to an institutional quality (no deferred maintenance) but not embarked on a comprehensive renovation program to date. Given the unbeatable location, larger than average unit sizes and top-notch amenity package, Mercury NoDa has the ability to reset the rental ceiling in the submarket. Current in-place rents are ~$0.50 PSF below neighboring comps.
20% Below Replacement Cost: At $275K per unit Mercury Noda is ~20% below replacement cost of $340K per unit. Furthermore, rents would need to increase by 40% for a developer to build Mercury NoDa today and achieve a 6.5% RoC (Full analysis provided in the OM).
Location: Mercury NoDa’s location at one of Charlotte’s most iconic intersections (36th and North Davidson) creates the epicenter of the Noda arts and entertainment neighborhood. The walkability rivals any asset in Charlotte with access to the light rail (2 blocks), a grocery store (Summer 2025 – 3 blocks), and an abundance of local shops, restaurants and live music venues.',TRUE,TRUE,''),
('Integra Cove Apartments','6 - Passed','Orlando, FL',338,2015,270710,91500000,'2024-09-10','2024-08-08','2024-09-10','All Docs Saved  - Guidance on Integra Cove is $91.5M or $270K per door, which is a 5% cap on trailing tax and insurance adjusted numbers and a mid 5% Yr. 1 underwriting a light value-add upgrade and 3% rent growth.
 
Integra Cove is a well-maintained 2015-built, 4-story elevator-serviced garden asset located in the heart of Orlando’s tourist corridor adjacent to SeaWorld and less than 10 minutes from Walt Disney World, Universal Orlando & Epic Universe, and the Orange County Convention Center, which total more 120K combined jobs with 15K more being added next year when Epic Universe opens. The asset has tremendous drive-by visibility and regional accessibility due to its location adjacent to Interstate 4, the Central Florida Parkway, and SR 528.
 
The property is currently 94% occupied, not offering any concessions, and features 100% original interior finishes that are prime for upgrading which will drive rents and compete with the newer deliveries in the market. Current ownership has added vinyl plank flooring into the bedrooms on all ground floor units which new ownership can expand upon to upper floor units as well as add hard surface counters in the bathrooms (currently formica), upgraded lighting and plumbing fixtures, new painted cabinetry, and more. There are additional revenue generating opportunities at play as you can also charge residents for the smart lock system which they’ve incorporated throughout the property and are not currently charging residents for.

Let us know if you have any questions or would like to tour.

We also have Apex Posner Park on the market, are you looking at that as well?',TRUE,TRUE,''),
('Marisol at Viera','6 - Passed','Melbourne-Titusville-Palm Bay, FL',282,2016,241134,68000000,'2024-06-12','2024-05-15','2024-09-06','all docs saved Update 9/6/24: This sold for $241k per door. It was a mid 4% on trailing, tax adjusted numbers due to the property being in the mid 80%''s occupied. Year 1 on a stabilized proforma it was around a 5.5%

Guidance on Marisol at Viera is $68M or $240K per door, which is a 5.8% cap rate on current rents, adjusted for stabilized occupancy with 2% concessions, post-sale taxes and insurance.
 
Marisol is 282-unit garden asset built in 2016 located in the center of the affluent Viera master-planned community of the Space Coast, one of the top 10 fastest growing master-planned communities in the country. The property is walkable to over 1.3M SF of destination retail and restaurants including the Avenue at Viera and Shoppes at Lake Andrew as well as an additional 3.9M SF of commercial space. Residents also have convenient access to the Space Coast''s prominent employment centers including the Health First Hospital system as well as L3 Harris, Lockheed Martin, Northrop Grumman, Space X, Boeing and more.
 
The property benefits from strong onsite demographics with average household incomes of $106K annually which equates to 5x the average leased rent. New ownership will have the ability to tap into a highly affluent renter demographic and push rents upwards which are currently positioned $200-$300 below the nearby comps. Additionally, new ownership will have the opportunity to implement a light value-add scope to the entire property as all of the units are in their original condition from when it was built in 2016.
 
Please let us know what questions you have as you review or if you’d like to schedule a tour of the property.',TRUE,TRUE,''),
('The Belmont Apartments','6 - Passed','Raleigh-Durham-Chapel Hill, NC',312,1998,217000,67704000,'2024-08-22','2024-07-22','2024-08-19','All Docs saved Guiding to $215-220k/unit here Let us know if you have any questions as you dig in!',TRUE,TRUE,''),
('1760 Apartments','6 - Passed','Atlanta, GA',239,2017,251046,60000000,'2024-08-20','2024-07-22','2024-08-15','All Docs except OM Saved - This is a good one and we are excited to bring it to market.  It has been a strong performer for the current owner, Blaze Capital Partners, since they acquired it in late 2017.  All docs saved -We are guiding to upper-$240k/unit (approaching $60M+/-) which is an in-place, low 5% cap rate.  A few notes on the opportunity:

 2017 elevator-served, mid-rise construction, featuring 9’ and 10’ ceilings built by LIV Development and Mesa Capital Partners
The property has received tremendous rent growth over the last 30 days (6.4% growth) representing immediate rental upside. 30-day LTO supports 4.0%+ trade outs on renewals.
Current ownership has installed vinyl-plank flooring in 41% of units. Current interior scope includes granite countertops with undermount sink, espresso/mocha cabinetry, and stainless-steel appliances.
239 units are ready for a “next level” (“modernized”) renovation scope including complete vinyl-plank flooring installation, painting cabinets white, upgrade cabinet fixtures, upgrade lighting, install closet systems, and adding a tech package.  This unlocks a $150-$190/unit premium, supported by their resident demographic HHI of $100k+ (4.7x Income-to-Rent Ratio) and surrounding comps.',TRUE,TRUE,''),
('The Lodge at Lakecrest','6 - Passed','Tampa-St. Petersburg-Clearwater, FL',464,2008,252155,117000000,NULL,'2024-08-14','2024-08-14','All Docs Saved - Initial pricing guidance is $117M, $252k/unit, $226/SF, which is a 5.3% T3 adjusted for current economic vacancy and market oriented opex (current variable expenses are $5.8K/unit a year vs. market avg of $4.5K).

Built by Hanover/MetLife (MetLife later bought Hanover out), Lodge has been institutionally owned and operated under one owner since its original development in 2008.  

Note that the spikes in vacancy and concessions are due to ownership pulling 15 units offline this spring, which they originally planned to renovate before electing to sell this summer.  They have now relet those units and are currently 95% occupied and 96.5% leased with no concessions being offered (in line with their historical norm).  As such the actual T3 is closer to a mid 4% cap but that will trend back to a low 5% through marketing.',TRUE,TRUE,''),
('Cortland North Druid Hills','6 - Passed','Atlanta, GA',310,2016,267741,83000000,'2024-08-13','2024-07-24','2024-08-14','All Docs saved- 
Pricing is $83M ($267K/Unit), which is a 5.11% cap rate (T3/T12 tax adjusted) and 5.96% cap rate (Year 1).
 
This is a rare opportunity to acquire a Core Plus, institutional asset in one of Atlanta’s highest barriers to entry submarkets.
 
The property is walkable to Emory and CHOA’s Executive Park (26K+ jobs). Since 2019, Cortland North Druid Hills experienced 25% property level rent growth and maintained occupancy of 95%, proving the resiliency and demand for this asset and location.',TRUE,TRUE,''),
('Bainbridge Nona North','6 - Passed','Orlando, FL',251,2023,285000,71535000,'2024-08-21','2024-07-17','2024-08-13','All Docs Saved - We’re targeting $285k/unit, 5.25% cap rate. CFOs likely mid-August. Have you seen The Ivy deal we have in the market? $265k/u, 5.25% cap rate too. CFOs 8/1.',TRUE,TRUE,''),
('Ashley Park','6 - Passed','Richmond-Petersburg, VA',272,1988,176470,48000000,NULL,'2024-08-05','2024-08-12','Signed CA - Guidance is $48M at just north of a 6.00% adjusted in-place cap rate. Great basis and location adjacent to Chippenham Hospital – this asset has only traded hands through merger.. Cornerstone to Colonial to MAA (current owner). MAA has invested significant dollars in property upkeep with an overall strategy of resident retention/high occupancy leaving significant value-add upside in the interiors. Ownership implemented minor upgrades several years ago that included cabinet doors and wraps, flooring in wet areas/foyer, laminate counters, white appliances and lighting.  The submarket has extremely bullish future rent growth projections, with limited incoming supply.

 

Feel free to give me a call after your initial review to discuss in greater detail.',TRUE,TRUE,''),
('200 East','6 - Passed','Raleigh-Durham-Chapel Hill, NC',330,1999,200000,66000000,'2024-08-28','2024-07-24','2024-08-12','All Docs saved 
Thanks for reaching out on 200 East in Durham, NC. Pricing guidance is $200k-$205k/door on this one, which yields a low-mid 5% cap on T3 income over Pro Forma expenses. Below you will find the investment highlights, along with a link to the deal room where you can access financials. The OM will be available next Tuesday, July 30th. When would be a good time to hop on the phone to discuss the opportunity? Lastly, we will be hosting property tours starting next Wednesday and throughout the marketing campaign. Can we go ahead and get you on the calendar for a tour?

 

200 East // Built 1999 // 330 Units

 

New ownership has the opportunity to complete a light, interior value-add initiative with features that set in line with submarket comparables to increase rents. C&W recommends bringing all units to the same finish level, with new shaker cabinet fronts, undermount farmhouse sinks, stainless steel appliances, granite bathroom countertops and modern finishes, vinyl flooring in wet and common areas, and a modern technology/smart home package. Carrying out this initiative could result in annual revenue growth of $760k+.
Units already contain some of these features, but are not currently to a consistent finish level.
Since acquisition in 2018, ownership has injected over $2.5M into the property, completing projects such as:
Fresh exterior paint
Clubhouse/leasing office renovation
New signage
Water heater and HVAC replacements
Interior renovations
Various landscaping work
New pool furniture and equipment
Current effective rent is $1,479, leaving new ownership the opportunity to bridge the ~$349 delta between the subject property and the submarket leader, Candour House ($1,828).
Located in the heart of the Triangle, the surrounding 3-mile demographic makeup is unmatched, with average household income over $109k, 80% white collar jobs, and 63.8% renter population.
The East Durham submarket population is expected to grow by more than 23% through 2027, and ranks 1st among Triangle submarkets in average occupancy.
Residents of 200 East enjoy quick and easy access to a plethora of retail, dining and entertainment options, including:
Miami Blvd and Page Road Retail (less than 1 mile) – Chipotle, Starbucks, First Watch, Farmside Kitchen, Mex Contemporary Mexican, Page Road Grill, Panera Bread.
Brier Creek Commons (9 minute drive) – Chick-Fil-A, Target, HomeGoods, TJ Maxx, Dick’s Sporting Goods.
Parkside Town Commons (10 minute drive) – Harris Teeter, Whole Foods, Target, Chick-Fil-A, Jersey Mike’s, Golf Galaxy.
Only a 5 minute drive from the property is Research Triangle Park, home to over 300 companies and 65,000+ jobs, including IBM, Fidelity, Cisco, Pfizer, Apple, Net App, and Lenovo to name a few.
I-40 is less than a mile from the property, providing residents swift access to the interstate and easy connectivity around the Triangle and greater NC.',TRUE,TRUE,''),
('Vance at Bishop Union','6 - Passed','Dallas-Fort Worth, TX',302,2018,238410,72000000,NULL,'2024-07-25','2024-08-05','All Docs saved - getting Cap Rate for Essence
We are whispering $72,000,000, which is a substantial discount to replacement cost for a podium style property with ground floor retail.  This is approximately $230k/door for the residential plus some allocation to the retail, which is partially occupied.  Let’s set up a tour when you are available. 

 

We anticipate a bid deadline of August 16th.

 

Vance at Bishop Union Highlights:

Walk Score of 95 in Bishop Arts – In the heart of the dynamic and walkable Bishop Arts District of Dallas that is a destination for food, cocktails, shopping, and the arts
HEB Grocery – HEB Owns the site next door with a new grocery store on the schedule for development in the near future
Top of Market Luxury Product – The podium construction and class A+ finishes offer the highest quality apartments in Bishop Arts
Extensive Amenities Including Skydeck –
Skydeck has the best downtown views in Dallas
Multiple dog parks and a dog washing station
Coffee shop adjacent to the lobby
Beautiful resort-style pool with lap lane
Fitness Center with separate room for aerobics training
Conference Room, Bike storage, Clubroom, Etc…
Easy Access to Employers – Many employers are within minutes of this location including Methodist Hospital, Downtown, and Uptown
Historic Location – Bishop Arts is in a historic part of Dallas that includes the high-end neighborhood of Kessler Park and Stevens Park Golf Course
Revenue Upside with Additional Retail Leasing – The property includes approximately 24k of retail space that is partially occupied providing significant upside with additional leasing
Substantial Discount to Replacement Cost – The whisper pricing will be $100k+ below replacement cost
Offered Free & Clear',TRUE,TRUE,''),
('Aventon Gem Lake','6 - Passed','Orlando, FL',247,2024,388663,96000000,NULL,'2024-07-24','2024-08-01','All Docs Saved -  

Guidance is $96M, $390K/Unit. In addition to the items highlighted in the Teaser, see a few key deal points below –

 

This Maitland/Winter Park Corridor is arguably the most desirable area in the MSA. The 5 closest multi owners – Ares, Blackstone, CBREI, JPM, Starwood
LifeTime Fitness will be a catalyst for the balance of the lifestyle elements to come in nearby, which should give rents additional lift
Only 30 market-rate entitlements remain, so the neighboring parcel will need to go 55+
Zero multi development pipeline within 3.5 miles
 

Let us know if you’d like to talk through the deal/area on a Google Earth screenshare, or if you have any other questions at the moment.',TRUE,TRUE,''),
('Kinstead McKinney','6 - Passed','Dallas-Fort Worth, TX',376,2019,239361,90000000,NULL,'2024-07-15','2024-07-30','Al Docs except OM - Jay – whisper is $90 mm, let us know if you need anything else.',TRUE,TRUE,''),
('Radius at Donelson','6 - Passed','Nashville, TN',128,2021,NULL,NULL,NULL,'2024-07-24','2024-07-29','All Docs saved -',TRUE,TRUE,''),
('The Spectrum','6 - Passed','Richmond-Petersburg, VA',103,2015,201941,20800000,NULL,'2024-07-22','2024-07-25','All Docs saved - There’s a loan in place from Virginia Housing. 6.432% fixed. No I/O. Current balance is ~$9.7M. The deal can be bought free & clear as well. There is also a tax abatement in-place which should be very accretive. I have attached the Tax & Abatement Worksheet.

Asking Price: $20.8MM (If you take on the current Virginia Housing Loan or take a new Virginia Housing Loan then they would do a deal at $20,450,000).

PPU: $202K',TRUE,TRUE,''),
('The Dylan at Grayson','6 - Passed','Atlanta, GA',234,2020,235042,55000000,'2024-07-30','2024-07-10','2024-07-25','All Docs saved - Regarding Dylan at Grayson, price guidance is $55 to $56M+ ($240K+/unit) around a 5.25% cap trending higher. It is a 5.5% cap FY1 which is pretty attractive for four year old product. Some of the of the key highlights: 2020 vintage, garden product (farmhouse design) built by South City and currently owned by National Property REIT Corp, a subsidiary of Prospect Capital. Fully stabilized with occupancy in the 95% range and virtually no bad debt (AR balance ~ 0.1%)
Excellent Grayson location (Gwinnett County) with highly rated schools and demographics (HHI: $123K, AHV: $380K, 71% college educated)
Limited supply in Grayson with only 4 properties built since 2000. By the way, rent roll now at $1,730 | $2.05, but 32 right-sized leases dating back to the end of May are pushing $2.10/SF ($1,756/unit). When we launched, GPR was at $1,722. Solid leasing volume as well, as 22 leases started in June, and 10 already started in July through 10 days. Current occupancy now up to 96%.',TRUE,TRUE,''),
('Avana Westchase Apartments','6 - Passed','Tampa-St. Petersburg-Clearwater, FL',400,2002,280000,112000000,NULL,'2024-07-15','2024-07-23','All Docs saved  - Guidance is $280k per unit/$240 PSF. Materials were finalized this morning, and you should have received an access email from RCM.

 

Let us know of any issues gaining access and a good time to talk through further.',TRUE,TRUE,''),
('700 Constitution Apartments','6 - Passed','Washington, DC-MD-VA',139,1910,323741,45000000,NULL,'2022-02-25','2024-07-22','all docs saved
**Updated guidance 45-47M, I think low 40Ms is worth offering based on his comment when I asked if they were definitely going to sell and he said there is a number where they wont sell, I don''t think 40M will get it done
-"50-55M (50-51M BOV), Land Lease"',TRUE,FALSE,''),
('Calirosa Winter Park Active Adult Apartments','6 - Passed','Orlando, FL',178,2022,280898,50000000,'2023-05-10','2023-04-06','2024-07-22','coming soon
Active Adult 55+
guiding $280s per unit. Should have the full deal room finalized later today or in the morning.',TRUE,TRUE,''),
('Walden Ridge','6 - Passed','Atlanta, GA',210,2002,215000,45150000,'2024-08-06','2024-06-27','2024-07-22','all docs saved 

215k per Will (talked to David)
Walden is a high-quality 2002-built Cobb County asset that is a value-add opportunity and management turn-around play.  Management changed 6-months ago and those results are just now showing up in the May T1-T3 statements.  For that reason, those are the ones to focus on.

Consider:
1) Prior management upgraded 40% +/-  of the units at $150 premiums but failed to install vinyl floors & washer dryers in that upgrade. Had those been installed premiums would be $250, consistent with competitors’ premiums. 

2) Not only can 60% of the units be upgraded from classic to luxury status at $250 premiums, but the initial 40% prior upgrades can be retrofitted with vinyl floors and washer dryers for an additional $100.  

2) Prior management allowed occupancy to drop during the 2023-2024 winter months explaining why vacancy was 8%. New management has returned it to 96%

3) Prior management allowed bad debt to rise to 2%-3%. New management is now trending at 1/2%.

Our valuation is in the $217,000 to $220,000/door range which represents is a 5.25% stabilized going-in cap rate (no rent growth) on Adjusted May T1

There is over 100 bps of rental upside making the Year 1 yield close to 6.25%.  

We are currently scheduling tours for Tuesday/Wednesdays. Let me know if you would like to set that up or schedule a call.',TRUE,TRUE,'')
ON CONFLICT (name) DO NOTHING;

INSERT INTO deals (name,status,market,units,year_built,price_per_unit,purchase_price,bid_due_date,added,modified,comments,flagged,hot,broker) VALUES
('Vida Winter Garden','6 - Passed','Orlando, FL',250,2021,310000,77500000,'2024-07-25','2024-07-01','2024-07-22','all docs saved - We are guiding $310-315k per unit. It last traded coming out of lease-up in 2022 for $428k per unit.

Really unique, barriered location on Plant Street just east of Downtown Winter Garden w/ easy access to 429 in both directions. Ownership has been through two management companies, and rents are considerably lower than where they should be. Also, please note the annotations in the financials as many of their controllables are well outside of market.',TRUE,TRUE,''),
('The Park At Salisbury','6 - Passed','Richmond-Petersburg, VA',320,2004,245312,78500000,NULL,'2024-06-06','2024-07-18','Guidance - $78.5m or $245k/unit.  Has full term I/O debt at 3.84% with 5 years left. Roughly $38.7m loan and with a $12.485m I/O supplemental can size to a 65+% LTV at a blended rate of 4.79% 

Cap rate - 5.6% on T3/T12 tax adjusted trailing and 5.9+% on first year.  IRR over a 18+%.  NOI per unit on T-3/T-12 is $13, 903 after reserves of $291/unit.',TRUE,TRUE,''),
('Garden Springs Apartments','6 - Passed','Richmond-Petersburg, VA',212,2010,235849,50000000,NULL,'2024-06-04','2024-07-18','Guidance - $50m or $236k/unit.? Has full term I/O debt at 3.84% with 5 years left. Roughly $25m loan and with a $6.75m I/O supplemental can size to a 63+% LTV at a blended rate of 4.54% 

Cap rate - 5.7% on T3/T12 tax adjusted trailing and 6%+ on first year.? IRR approaches a 20%. NOI per unit on T-3/T-12 is $13, 631 after reserves of $337/unit.',TRUE,TRUE,''),
('Lumen Doraville','6 - Passed','Atlanta, GA',320,2023,304687,97500000,NULL,'2024-07-11','2024-07-18','All Docs Saved - Jay—toured Will last week.  Shooting for $97.5m but we should discuss the nuances, they are important to understand',TRUE,TRUE,''),
('South Tryon','6 - Passed','Charlotte-Gastonia-Rock Hill, NC-SC',216,2002,200000,43200000,'2024-07-18','2024-07-01','2024-07-18','All docs saved Seller wants to hit ~$200k per unit which is a 5.75% in-place cap rate. This one has a short fuse, let us know if we can answer any other questions.',TRUE,FALSE,''),
('Eastside Heights','6 - Passed','Nashville, TN',249,2017,260000,64740000,'2024-07-31','2024-07-01','2024-07-18','All docs saved  -- Guidance is in the $260 per door range. IO runs thru the end of the year. The leverage is really helpful however (more of an IRR play than cash-on-cash). 

-	The seller is Steadfast (specifically Rod Emery)
-	They purchased in 2019 for $64.2MM
-	Existing debt: 
o	Fannie
o	$45,475,000 original and current balance
o	3.5% rate
o	Originated 12/1/19
o	Matures 11/1/29
o	IO period 60 months
-	7,435 SF of retail, 2 suites occupied (3,375 SF, with rents in the low $30’s), both users have bene there since the beginning with expirations in 2027/2028.',TRUE,TRUE,''),
('Lake Cameron','6 - Passed','Raleigh-Durham-Chapel Hill, NC',328,1999,197000,64616000,'2024-07-31','2024-07-09','2024-07-18','All docs saved - Guiding to $195-200K/unit here',TRUE,TRUE,''),
('Populus Pooler','6 - Passed','Savannah, GA',316,2023,262658,83000000,'2024-07-31','2024-07-09','2024-07-18','All docs saved - 
Pricing guidance is $83M ($263K/unit) which is a 6.21% Y1 cap rate which is inclusive of the 2024 tax appeal value.
Developed by The Novare Group, Populus Pooler is one of the premier assets in the submarket.
Populus Pooler is a premier asset strategically located in one of the Sunbelts’ highest growth submarkets and is poised to benefit from Hyundai’s $5.5B manufacturing facility that is 15 minutes away from the site that will lead to 40K+ total new jobs.
The property has an impressive average household income of $110K with employers such as Amazon, Gulfstream, and Memorial Health.
Impressive fundamentals, population migration, and the strong velocity at Populus Pooler provides real rental upside on 2nd generation leases.
Initial Call for Offers will likely be late July.',TRUE,TRUE,''),
('930 Central Flats','6 - Passed','Tampa-St. Petersburg-Clearwater, FL',218,2019,366972,80000000,'2024-07-24','2024-07-01','2024-07-18','All docs saved $80M, $367k per unit, 5% cap year 1.',TRUE,TRUE,''),
('The Shelby Apartments','6 - Passed','Washington, DC-MD-VA',240,2014,320833,77000000,'2024-07-26','2024-06-26','2024-07-18','All docs saved Looking for high $70s which is a low to mid 5s cap on in place and $320k/unit.
https://properties.berkadia.com/the-shelby-464667/p/1
- Guidance is upper $70’s ($320k/unit) which is a 5.25-5.5% cap on inplace 
- Located in Alexandria, VA just south of Huntington Metro (walkable – less than 0.5 miles)
- Asset is performing very well and is getting 10% YTD on trade outs 
- There is light value add upside (new FF&E, refresh in units), the new lease up (Aventon Huntington Station) is getting $500/mo++ higher in rents 
- 29th Street Capital is the Seller
- CFO is 2 weeks out',TRUE,TRUE,''),
('Monterra Village','6 - Passed','Fort Worth, TX',550,2008,190000,104500000,'2024-07-30','2024-07-08','2024-07-18','All docs saved Guidance - $190k/u +
Phase 1 Built - 2008 Phase 2 Built - 2013',TRUE,TRUE,''),
('Commonwealth Apartments','6 - Passed','Richmond-Petersburg, VA',234,2022,256410,60000000,'2024-07-24','2024-07-03','2024-07-18','All docs saved - We’re guiding to $60M here. Key takeaway is the basis, at sub $260K/unit. There is a deal right next door built in the 1980s (Hunters Chase) that sold for $248k/unit. The location is incredibly strong, walking distance to a Fresh Market and other high quality retail. New for sale development is a common theme nearby as well. Happy to jump on a call to chat further.',TRUE,TRUE,''),
('Manassas Station Apartments','6 - Passed','Washington, DC-MD-VA',244,2009,274590,67000000,'2024-08-06','2024-07-03','2024-07-18','All Docs saved. East Built 2017, West Built 2009/2012

Looking for $66-68mm which is $275k/door and a 5.25-5.5% on T-3/T-12 RE Tax adjusted.  Rents are up between 8-9% on recent 30/60/90 and there’s a ton of value add potential. 
16 of the 2x2''s have den''s (can''t model on RedIQ) - EJ
Guidance is mid-60s which is 5.5% cap on inplace 
- Strong performing asset, rents are up 9% on recent 30/60/90 day trade outs
- Blank slate for in-unit value-add, 9-foot ceilings, huge units 
- Two assets operated together (about one block from each other) that bookend the VRE station, which is main transportation mode for residents 
- CAPREIT / Principal seller 
- CFO will be end of July',TRUE,TRUE,''),
('Residences at Crosspoint Apartments','6 - Passed','Lowell, MA-NH',240,2020,350000,84000000,NULL,'2024-07-01','2024-07-18','All docs saved We are anticipating pricing in the $83-$85 million range ($346-$354k/unit), which equates to a cap rate on in-place rent roll of 5.37%-5.50%, with limited tax risk. The asset is free & clear of debt. The Residences at Crosspoint is a rare 100% market-rate opportunity. Completed in 2020, the community is nearly 100% leased and has seen new lease trade outs of 8.2% since October (49 leases), while in-place rents are $429 or 18% below the weighted average rent throughout the competitive market. The Residences at Crosspoint is located adjacent to the 1.2 MSF Crosspoint office complex (home to IBM & UKG/Kronos) and is at the intersection of Route 3 and I-495, offering convenient access throughout the Route 3, 495, and Route 128 employment hubs. As podium construction with a wrap parking garage, the property offers a differentiated suburban product and will trade at a significant discount to replacement cost.',TRUE,FALSE,''),
('IMT Maitland Pointe Apartments','6 - Passed','Orlando, FL',392,2017,255000,99960000,NULL,'2024-07-01','2024-07-18','All docs saved $255-$260k/unit',TRUE,TRUE,''),
('Sedgewick','6 - Passed','Washington, DC-MD-VA',92,NULL,NULL,NULL,NULL,'2020-03-05','2024-07-18','',TRUE,TRUE,''),
('Arbor Ridge on West Friendly Apartments','6 - Passed','Greensboro--Winston-Salem--High Point, NC',304,1983,NULL,NULL,NULL,'2020-03-16','2024-07-18','',TRUE,TRUE,''),
('Ventura at Turtle Creek Apartments','6 - Passed','Melbourne-Titusville-Palm Bay, FL',190,2019,NULL,NULL,NULL,'2020-03-06','2024-07-18','',TRUE,FALSE,''),
('Montage Embry Hills','6 - Passed','Atlanta, GA',225,2008,NULL,NULL,NULL,'2020-03-09','2024-07-18','',TRUE,TRUE,''),
('Wilde Lake Apartments','6 - Passed','Richmond-Petersburg, VA',190,NULL,NULL,NULL,NULL,'2020-03-06','2024-07-18','',TRUE,TRUE,''),
('Windsor Falls Apartments','6 - Passed','Raleigh-Durham-Chapel Hill, NC',276,1994,140000,38640000,NULL,'2020-05-05','2024-07-18','Seller looking for $155k / unit. We valued it at about $140k / dr and made offer in mid-May. No for now, but Seller expectations may be coming down',TRUE,TRUE,''),
('Carrington Park','6 - Passed','Raleigh-Durham-Chapel Hill, NC',266,2007,165413,44000000,NULL,'2020-05-05','2024-07-18','Seller is asking for high 190''s / unit. we valued and offered at about 165k. Seller firm on price but indications they may be coming down to more realistic pricing. 

subject to loan assumption',TRUE,TRUE,''),
('The Point at Westside','6 - Passed','Atlanta, GA',267,2004,186142,49700000,NULL,'2020-03-19','2024-07-18','Was broadly marketed in Feb, pulled off and put on shelf indefinitely after shutdown

Still on hold per broker as of 6/16',TRUE,TRUE,''),
('Sunstone Apartments','6 - Passed','Raleigh-Durham-Chapel Hill, NC',236,1985,144067,34000000,NULL,'2020-07-24','2024-07-18','7/24

CB working to finalize listing agreement, will be together with Shadowood (common owner - Solomon)',FALSE,TRUE,''),
('Shadowood Apartments','6 - Passed','Raleigh-Durham-Chapel Hill, NC',336,1989,145833,49000000,NULL,'2020-07-24','2024-07-18','7/24

CB looking to bring to market together w SunStone',FALSE,TRUE,''),
('Plantation Gardens Apartments','6 - Passed','Tampa-St. Petersburg-Clearwater, FL',329,2001,185410,61000000,'2020-10-14','2020-06-04','2024-07-18','$60-$61MM',TRUE,TRUE,''),
('Matthews Pointe Apartments','6 - Passed','Charlotte-Gastonia-Rock Hill, NC-SC',100,1986,NULL,NULL,NULL,'2022-02-18','2024-07-18','no deal room yet
-Part of the Charlotte Suburban Value-Add portfolio',FALSE,TRUE,''),
('Mezzo Apartment Homes','6 - Passed','Atlanta, GA',94,2008,NULL,NULL,NULL,'2020-07-28','2024-07-18','"we called for offers over a month ago. The company is undergoing a restructuring, so the deal is on hold for now." per 10/1/20',FALSE,TRUE,''),
('Cortland Lex','6 - Passed','Atlanta, GA',360,1996,236111,85000000,NULL,'2020-09-08','2024-07-18','$85M+; no war room yet per 10/1/20; also no CFO date yet...',FALSE,TRUE,''),
('Development Site in Forest Hill','6 - Passed','Richmond-Petersburg, VA',35,NULL,NULL,NULL,NULL,'2021-01-22','2024-07-18','could either be subdivided into 35 single-family detached parcels or 65 attached parcels and units ; he didn''t give me pricing for this b/c it''s already under contract',FALSE,TRUE,''),
('Southeastern Oaks Townhouse Development','6 - Passed','Orlando, FL',168,NULL,29761,5000000,'2021-01-27','2021-01-22','2024-07-18','entitled for 168 townhomes ; 5M range',FALSE,TRUE,''),
('Park At Crossroads Apartments','6 - Passed','Raleigh-Durham-Chapel Hill, NC',344,2005,NULL,NULL,NULL,'2021-01-22','2024-07-18','coming to market soon',FALSE,TRUE,''),
('Southpoint Village Apartments','6 - Passed','Raleigh-Durham-Chapel Hill, NC',211,2008,NULL,NULL,NULL,'2021-01-14','2024-07-18','Kees talked to Gino...will be officially marketed and we will try to get a chance to offer early.  Brookfield deal.',FALSE,TRUE,''),
('NOTCH','6 - Passed','Tampa-St. Petersburg-Clearwater, FL',112,2021,NULL,NULL,NULL,'2021-02-01','2024-07-18','not on market yet ; sent by Elliott Throne to Will',FALSE,TRUE,''),
('HITE','6 - Passed','Tampa-St. Petersburg-Clearwater, FL',81,2018,NULL,NULL,NULL,'2021-02-01','2024-07-18','not on market yet ; Elliott Throne sent to Will',FALSE,TRUE,''),
('Vinings at Laurel Creek','6 - Passed','Greenville-Spartanburg-Anderson, SC',244,2003,163934,40000000,NULL,'2021-01-14','2024-07-18','40M whisper price',TRUE,TRUE,''),
('St. Johns Wood','6 - Passed','Washington, DC-MD-VA',250,1989,280000,70000000,NULL,'2021-01-27','2024-07-18','JP Morgan built w Bozzuto, bought Bozzuto out in late 2000s and owned by itself ever since

still managed by bozzuto

may be opportunity to walk in an offer and shake it loose. Brian to provide some more color and we will do BOE underwriting',FALSE,TRUE,''),
('Level at 401','6 - Passed','Raleigh-Durham-Chapel Hill, NC',300,2014,NULL,NULL,'2021-04-22','2021-03-25','2024-07-18','',FALSE,TRUE,''),
('Alexan Eight West','6 - Passed','Atlanta, GA',264,2020,NULL,NULL,'2021-04-28','2021-03-22','2024-07-18','',FALSE,TRUE,''),
('616 at the Village Apartments','6 - Passed','Raleigh-Durham-Chapel Hill, NC',207,2017,299516,62000000,NULL,'2021-07-28','2024-07-18','Coming soon / maybe can jump beforehand

2017 core / core + deal with some (minor) VA opportunity',FALSE,TRUE,''),
('Mission Matthews Place Apartments','6 - Passed','Charlotte-Gastonia-Rock Hill, NC-SC',392,1994,NULL,NULL,NULL,'2022-02-18','2024-07-18','no deal room yet
-Part of the Charlotte Suburban Value-Add portfolio',FALSE,TRUE,''),
('Waterford Hills Apartments','6 - Passed','Charlotte-Gastonia-Rock Hill, NC-SC',270,1995,NULL,NULL,NULL,'2022-02-18','2024-07-18','no deal room yet
-Part of the Charlotte Suburban Value-Add portfolio',FALSE,TRUE,''),
('Ellicott House Apartments','6 - Passed','Washington, DC-MD-VA',327,1974,290519,95000000,NULL,'2022-06-02','2024-07-18','all docs saved
off mkt from Bobby',TRUE,TRUE,''),
('The Rise Plantation Walk','6 - Passed','Fort Lauderdale-Hollywood, FL',404,2021,358910,145000000,'2024-07-18','2024-07-01','2024-07-17','All docs saved -  Target pricing for the multifamily is $360,000 per unit.  Stabilized Cap Rate here is right around 5%. There is a strong replacement cost story here as the cost for midrise today would be in the low to mid $400k per unit.
In addition to the multifamily component, the retail and phase II development site are available as well. The retail includes over 128K SF that is 72% occupied and 86% leased and the development site is approved for an 8-story midrise project with 297-units.',TRUE,TRUE,''),
('Hideaway Townhomes','6 - Passed','Washington, DC-MD-VA',200,1998,237500,47500000,NULL,'2024-07-12','2024-07-15','All Docs Saved - Guidance "Hey Jay 47.5"',TRUE,TRUE,''),
('Evoq Town Flats at Johns Creek','6 - Passed','Atlanta, GA',140,2019,328571,46000000,NULL,'2024-07-01','2024-07-15','All docs saved signed CA
WB tour - did not like it and felt it could not be fixed (similar to calirosa)
55+
Pricing should be in the +/- $46M range, which is a stabilized 5% cap.  Let us know if you would like to discuss further.  We should be releasing the information after the 4th of July Holiday.',TRUE,TRUE,''),
('The Quaye at Wellington','6 - Passed','West Palm Beach-Boca Raton, FL',350,2017,405000,141750000,'2024-07-10','2024-07-01','2024-07-11','All docs saved - Guidance on The Quaye is around $405k per door or $295 per foot, and works out to an in-place 5% cap or north of a 6% cap with the core+ renovation upside fully baked in. 
 
70% of the units are townhomes with direct access garages, with units sizes averaging 1,374 square feet.

The property is zoned for A-rated schools, so the product is perfect for families with school-age children.

Last but not least there is an existing 3.88% fixed rate assumable loan in-place, maturing in June 2028 with full-term I/O remaining, which might serve as a bridge to lower rates.',TRUE,TRUE,''),
('Canopy at Citrus Park','6 - Passed','Tampa-St. Petersburg-Clearwater, FL',318,2018,292452,93000000,'2024-07-10','2024-06-06','2024-07-11','All docs saved Pricing guidance is $93 million (about $290,000 per unit), which yields a cap rate of approximately 5.0% on in-place, and mid 5’s when bringing the rents to be in line with its comp set.    With operational upside and value-add potential, the stabilized cap rate is 6.2%.   At $290,000 per unit, the pricing is below replacement cost, especially so considering how challenging it would be to replicate the asset in this location.',TRUE,TRUE,''),
('Cortland Bellevue','6 - Passed','Nashville, TN',322,2016,270186,87000000,'2024-07-05','2024-05-09','2024-07-11','all docs saved

Thanks for reaching out on Cortland Bellevue, a 2016-vintage, 322-unit multifamily community located in one of Nashville’s top performing submarkets, Bellevue.  This core-plus opportunity provides an investor high quality real estate in the booming Nashville market within a submarket that has historically been tough to enter given the muted supply pipeline. As a result of the tempered growth of the submarket and the attractive demographics of the area ($91k/ median HH Incomes), Bellevue boasts some of the highest suburban rents in Nashville.  

Cortland Bellevue is a prime example of the submarket description and presents a great opportunity to buy a well located asset that generates attractive returns with the upside potential for accretive investments in unit interior upgrades.  The property is in excellent condition and recently completed a pool deck/FFE replacement project. 

Guidance is $87mm ($270k/door) which represents about a 10%+ discount to replacement cost and a 5.1% cap rate (tax adjusted/franchise tax inclusive) on T-12 figures. A CFO date will be set shortly but please reach out with any questions in the interim.  We look forward to speaking soon and are happy to set up a tour at your convenience.',TRUE,TRUE,''),
('District at Duluth','6 - Passed','Atlanta, GA',370,2018,250000,92500000,'2024-07-10','2024-06-27','2024-07-11','all docs saved
250/unit per Will (talked to David)',FALSE,TRUE,''),
('Cortland Preston North','6 - Passed','Dallas-Fort Worth, TX',350,2017,234285,82000000,'2024-06-26','2024-05-23','2024-07-11','all docs saved

Pricing guidance here is approaching $240k/unit (low-$80mm range), which equates to a ~5% in-place cap rate (t3/t12 tax and insurance adjusted).',TRUE,TRUE,''),
('Westbrooke Place','6 - Passed','Washington, DC-MD-VA',201,1995,452736,91000000,'2024-06-18','2024-05-15','2024-07-01','Low 90s million, mid-5 cap, Clarion owns…',TRUE,TRUE,''),
('Marden Ridge Apartments','6 - Passed','Orlando, FL',272,2017,238970,65000000,NULL,'2024-04-30','2024-07-01','all docs saved

Marden Ridge deal – 9’ ceilings, great floor plans, big amenity space.  Pricing probably $67-$65MM range (good bit below replacement cost). Highly accessible deal in North Orlando less than 1 mile from new hospital in Apopka and just minutes from Maitland, Winter Park, and Winter Garden.  Property has some easy upside as well.',TRUE,TRUE,''),
('Trail Creek','6 - Passed','Norfolk-Virginia Beach-Newport News, VA-NC',300,2008,241666,72500000,NULL,'2024-06-03','2024-07-01','Low to mid $70s million, ?which is roughly a 5.5% Cap on T3/T12 tax adjusted financials. That said, there is incredibly accretive debt in-place, totaling $44,017,000 between the senior and supplemental. Additionally, we are sizing an additional $5-5.5M on a second supplemental, to bring you from 60% leverage to 67%+ at an approximate rate of

Phase 1: 2006 204 Units 
Phase 2: 2012 96 Units 

 In-Place accretive Debt: blended rate of 4.45% with 31 months remaining of IO.  Additional supplemental can size up to a 1.25 DSCR at roughly 300bps over treasuries.',TRUE,TRUE,''),
('The Current at Watershed Townhomes','6 - Passed','Baltimore, MD',97,2023,556701,54000000,NULL,'2024-05-21','2024-07-01','all docs saved

townhome deal near ft meade - JS

We are guiding $54M and a 5.56% Cap Rate.',TRUE,TRUE,''),
('Cortland Perimeter Park','6 - Passed','Raleigh-Durham-Chapel Hill, NC',262,2018,267175,70000000,'2024-05-22','2024-04-25','2024-07-01','all docs saved
Thanks for reaching out. We’re guiding $260s per unit and CFO will be 5/22. 

The OM will be available the week of April 29th. 

Cortland Perimeter Park is located in the heart of RTP (60,000 jobs). The blue chip rent roll has an average HHI of $115K which translates to a 20% rent to income ratio. The asset has been institutionally owned and operated since delivering and offers a compelling rent discount to newer construction that can be closed through a light value-add. 

Cortland Perimeter Park / 2018 Vintage / 262 Units
•	Perimeter Park is Located adjacent to Research Triangle Park (RTP) – the largest research park in the United States home to over 60,000 employees and 375 companies. 
•	5 minutes away from Apple’s $1 Billion, 281-acre campus bringing 3,000 jobs with an average salary of $187,000 breaking ground in 2026 
•	$150 / $0.30 PSF discount to top of market new construction. 
•	Discount to replacement cost of $285K/unit. 
•	Barriers to entry in the submarket: It is difficult to get a rezoning approved in Morrisville, and the hard exterior material (ie stone façade) requirements combined with taps fees add a substantial amount to all-in cost. 
•	Taxes – the property is 75% in Wake County and 25% in Durham County. 
o	Wake County is on a 4 year cycle and 2024 is a reassessment year. The 2024 value, which is locked in until 2028, is available on the data site. Tax rates will be voted on in June. The revenue neutral tax rate for Wake County is .45 which would imply a 29% rollback if adopted. 
o	Durham County is also on a 4 year reassessment cycle and will reassess in 2025.',TRUE,TRUE,''),
('The Retreat at Windermere Apartments','6 - Passed','Orlando, FL',332,2013,289156,96000000,'2024-05-29','2024-05-09','2024-07-01','all docs saved

talked to chip 5/9, 290/door, value-add 200+ prem, exterior painted 4 yrs ago, need to reno units and minor amenity improvements. great submarket and location. owned by LACERA and their entire portfolio is being sold by CBRE & Eastdil.',FALSE,TRUE,''),
('Cortland Gateway','6 - Passed','Tampa-St. Petersburg-Clearwater, FL',288,2021,288194,83000000,'2024-06-13','2024-05-15','2024-06-24','need to save docs

Guidance is $290k per unit. Working to finalize deal room and grant access today.

It’s differentiated product within the area (elevator-serviced, conditioned corridors, developed by Wood Partners) with very little new supply.',FALSE,TRUE,''),
('Preston View','6 - Passed','Raleigh-Durham-Chapel Hill, NC',382,2000,217277,83000000,'2024-06-12','2024-05-23','2024-06-24','all docs saved

$215-220K/unit',FALSE,FALSE,''),
('Sphere Apartments','6 - Passed','Richmond-Petersburg, VA',224,2024,236607,53000000,'2024-06-06','2024-05-06','2024-06-24','all docs saved

Per my voicemail message yesterday, I wanted to make sure that you saw our blast of Sphere in Richmond.  When we last spoke you were focused on NVA but wanted to put this one on your radar regardless because of the basis and asset quality.  Here is the link to the deal room for your convenience - https://multifamily.cushwake.com/Listings/30922.  I thought this deal could be a good fit for you.  We’re targeting $53m or ~$235k per unit which is a 5.75% cap rate which is well below replacement cost today.  The property is a Class A apartment community that is just now wrapping up lease up.  It''s located in downtown Richmond where there is significant economic growth just outside of Scott''s Addition, VCU, VUU and many of downtown Richmond''s revitalization projects (Diamond District & VUU''s expansion).  There is a ton to like about this deal. 

Also, we are prepping a two property portfolio in Fredericksburg that is more Core+ (fully renovated 90’s product).  Is that a market that you would pursue?  Let me know on both front and if you''d like to schedule a call to discuss in greater detail.  Hope you’re well and look forward to catching up soon.',FALSE,TRUE,''),
('The Landings at Boggy Creek','6 - Passed','Orlando, FL',310,2023,293548,91000000,'2024-06-20','2024-05-23','2024-06-24','signed CA 5.23

lake nona - hottest submarket in orlando, lots of white collar jobs kpmg etc. Joe Lewis currency trader did this master planned dev - 5.5 cap year 1.

Ask here is low $90M''s, low/mid $290k''s per door which is a low-5% on in-place rents and stabilized expenses. Year 1 will be close to a 5.5% Yr. 1 stabilized cap rate with concession burnoff and nominal growth, adjusted for post-sale taxes and insurance. Brad will follow up with you to set up a call.

The property is located in the coveted Lake Nona submarket and is surrounded by the area''s top employment centers including Lake Nona’s Medical City, the $500M KPMG Lake House, USTA National Campus, Amazon Robotics Fulfillment Center, Orlando International Airport, and more. Additionally, the property is only 2.5 miles from 4M+ SF of new destination retail and entertainment located within the Lake Nona Town Center.

Boggy Creek is the next major growth corridor in the submarket and is experiencing explosive growth coming in, very similar to what happened on Narcoossee Rd on the east side of Lake Nona the last 5 years. Boggy Creek Rd itself is currently undergoing a $90M, 5.9 mile infrastructure expansion which includes doubling the capacity of the road (now complete) and adding a new stoplight interchange into the property off Simpson Road. There is also a new Publix center less than 2 miles north and tons of new retail/restaurants including Nona West Shopping Center, Tavistock''s next 400K SF retail development, that are under construction between the property and SR 417 to the north. 

The property benefits from strong onsite and immediate area demographics with average household incomes onsite of $115K, average home values of $550K+, and 145%+ population growth since 2010. With onsite residents earning nearly 5X the average leased rent and asking rents positioned $200-$300 below the comps along Narcoossee Rd, new ownership will have plenty of runway on future rental increases post stabilization.',FALSE,TRUE,''),
('The Avery','6 - Passed','Orlando, FL',200,2022,270000,54000000,'2024-06-18','2024-05-23','2024-06-24','signed CA 5.23

5.25 in place / mkt exp, 5.5 year 1

Ask price on The Avery is $54M, $270k per door which is a 5.25% on March T1 income and proforma expenses. We are looking at proforma/market-oriented expenses as their trailing expenses are extremely heavy, specifically payroll and marketing, as the property was in lease-up over the last 12 months. Additionally, this is a smaller developer who over insures, so their insurance is much higher than what we have seen in the market recently (last 3 Class A garden deals that we have awarded/closed have had insurance premiums for the new buyer range from $900-$1150/unit). Regarding the catalyst for selling, this is your typical merchant build execution for them. 

This is a great boutique deal with incredible visibility and accessibility on SR 417 and SR 408 in East Orlando. The property is less than 2 miles from AdventHealth East Orlando, and with the accessibility, residents can be at UCF, downtown Orlando, or Lake Nona within 15 minutes.',FALSE,TRUE,''),
('Alders at Rockwall','6 - Passed','Dallas-Fort Worth, TX',144,2021,256944,37000000,'2024-05-22','2024-05-06','2024-05-20','all docs saved

We expect Alders Rockwall to trade in the $255K-$260K/Door range, putting you around 37M all-in and a 5.6% cap rate on in-place tax-adjusted NOI. CFO has not been set yet but expect it to take place middle of May.

This three-story active adult (62+) asset was built by Lone Oak Interests and is strategically located in the Dallas suburb of Rockwall. Rockwall County is the most affluent in the state with median household income greater than $120K. The property benefits from the expansion and modernization of highways I-30 & President George Bush Turnpike, which connect residents to core Dallas and Plano/Frisco respectively, as well as one of the lowest total millage rates in the state ($1.57 per $100 of assessed value).

Alders Rockwall benefits from very limited Class A seniors product nearby (this is the only new construction active adult community in Rockwall County). 

The asset is offered on both an all-cash and loan assumption basis; there is an assumable HUD loan at ~64% LTV with a fixed interest rate of 3.88% (loan details available in deal room). 

Additionally, post-sale tax-reassessments in Rockwall County have averaged 58.5% of purchase price over the past 2-3 years (see attached analysis), and the preliminary 2024 tax value for Alders is $78k per unit (~30% of guidance pricing).',FALSE,TRUE,''),
('Aurora on the Trail Apartment Homes','6 - Passed','Orlando, FL',361,2020,324099,117000000,'2024-05-22','2024-04-25','2024-05-20','all docs saved

loan assumption, 2.64% IO

Guiding $117M. Working to finalize OM & deal room, but should be ready by Monday.',FALSE,TRUE,''),
('The Lanes at Union Market','6 - Passed','Washington, DC-MD-VA',110,2023,340909,37500000,'2024-05-23','2024-04-16','2024-05-20','all docs saved

THIS OFFERING IS A FORECLOSURE SALE WITH AN IMMEDIATE LEGAL PATH TO FEE SIMPLE TITLE

Hard to say with an auction process, but probably $35M-$40M range.
  
The foreclosure sale for Lanes at Union Market is scheduled for May 23, 2024. The lender has the ability to credit bid up to a certain amount. If the buyer surpasses the lender’s final bid, the trustee will declare the buyer as the successful bidder, collect their deposit check, and have them sign a Purchase and Sale Agreement (PSA). Once this is completed, the buyer has a 60-day period to secure financing and proceed with closing the property. The buyer has the flexibility to choose their own title company for the settlement process. The trustee will then deliver the deed to the selected title company. The borrower is not directly involved in the foreclosure process; instead, it is the trustee who handles the deed delivery. A non-refundable deposit of $1,000,000 is required, and there is no study period allowed after the auction.  According to Codes §42–3404.02.(c)(2) and §42–3404.02.(d)(1) of the District of Columbia, foreclosure sales are not considered “sales” under the Tenants Opportunity to Purchase Act (“TOPA”).',FALSE,TRUE,''),
('Bell Stonebridge Apartments','6 - Passed','Washington, DC-MD-VA',308,2014,308441,95000000,'2024-05-22','2024-04-30','2024-05-20','all docs saved

Guidance is $95M.',FALSE,TRUE,''),
('Braxton at Lake Norman','6 - Passed','',232,2014,250000,58000000,'2024-05-09','2024-04-04','2024-05-14','no OM 4/4, dn save any docs yet
•	$250s/u
•	large 1,055 sf units
•	nearly half the units with attached garage
•	private entry
•	original interiors / potential for light value-add or a bigger scope 
•	just under 5% cap on 3.6% assumable Freddie debt',FALSE,TRUE,''),
('Charleston on 66','6 - Passed','Tampa-St. Petersburg-Clearwater, FL',258,2018,279069,72000000,'2024-05-14','2024-04-10','2024-05-14','all docs saved
Initial guidance is $72M, $2c80k per unit, which is a 4.8% T3 tax adjusted, 5.2% YR 1 (7% vacancy trailing now 5% with no concessions currently).  The loan is 52% LTV at 3.43% full term IO through 11/2029.',TRUE,TRUE,''),
('Cortland Whitehall','6 - Passed','Charlotte-Gastonia-Rock Hill, NC-SC',271,2018,NULL,NULL,'2024-05-07','2024-03-27','2024-05-14','all docs saved',FALSE,TRUE,''),
('Bellemeade Farms Apartments','6 - Passed','Washington, DC-MD-VA',316,1988,262658,83000000,'2024-04-30','2024-04-04','2024-05-06','signed CA 4/4

We are guiding toward $83 mm ++ | $260 K per unit | 5.7% in-place (tax adjusted) cap rate | 6.7% post renovation pro forma cap rate.  The rent growth and value-add upside are major drivers.  263 of the 316 units have some level of value add that can be incorporated.  The property is rolling:  13 New Leases are 7.8% higher from 2/4/24, 28 Renewal Leases are 6.3% higher from 2/4/24 | June Renewal Letters range from 7.0% to 10.0% higher.  

There’s a Fannie Mae loan that can be assumed - $45.337 mm | 4.30% rate | Amortization commences 4/2024 | Matures 3/2029 | ~$7 mm supplemental proceeds available to 65% LTC - With the amortization kicking in, not sure how accretive it is but worth looking at.  We are getting a quote for the supplemental loan proceeds.',TRUE,TRUE,''),
('Novus Westshore','6 - Passed','Tampa-St. Petersburg-Clearwater, FL',260,2016,346153,90000000,'2024-04-10','2024-03-27','2024-05-06','all docs saved
Jay – guidance is $90M. Key deal points below – 

•	Unique core-plus opportunity still owned by the developer (Northwood Ravin)
•	$50M Freddie floater w/ 4.5% rate capped for 2 years, 7 years total term remaining (can use as bridge and refi in a better capital markets environment)
•	Differentiated product (for-sale quality interiors, 10’ ceiling heights 40% units, whirlpools, dry saunas, resort-pool, seamless access/building logistics)
•	Clean, historical operations with trending new leases/renewals (4%) and desirable renter profile (diverse employment, $195K Avg HHI)
•	Barriers – no pipeline within 1.5 miles (only 1 project built last 7 years – sold for north of $600k/unit)
•	Upside (untouched interiors) – new lighting/plumbing fixtures, front control range, plank in bedrooms, closet systems, smart thermostats, bulk cable/internet package',FALSE,TRUE,''),
('The Apartments at Shade Tree','6 - Passed','Charleston-North Charleston, SC',248,2015,245967,61000000,'2024-04-23','2024-03-27','2024-05-06','all docs saved
Thanks for reaching out on Shade Tree. We are very excited about the deal as it checks all of the boxes for a great core+ opportunity. The barriers to entry on Johns Island will keep the pipeline limited forever, creating a fortress location and the foundation for a generational hold.

Guidance is in the low $60Ms which translates to a lower 5 cap on T3/T12 (tax and insurance adjusted). We look forward to connecting with you on this unique opportunity.',FALSE,TRUE,''),
('The Tiffany at Maitland West','6 - Passed','Orlando, FL',315,2018,238095,75000000,'2024-04-10','2024-03-27','2024-05-06','all docs saved
Regarding pricing will probably be in the $75 - $80 million range ($240,000s-$250,000 per unit) 
Like 5.4-5.5 cap rate',FALSE,TRUE,''),
('Vintage Lake Mary Apartments','6 - Passed','Orlando, FL',310,2023,290322,90000000,NULL,'2024-02-06','2024-03-27','signed CA 2/6',FALSE,TRUE,''),
('CERU','6 - Passed','West Palm Beach-Boca Raton, FL',284,2022,NULL,NULL,NULL,'2024-02-06','2024-03-27','all docs saved',FALSE,TRUE,''),
('501 East 74th Street','6 - Passed','New York, NY-NJ',84,2016,690476,58000000,NULL,'2024-02-24','2024-03-27','all docs saved
from Greystar, co-invest opportunity',TRUE,TRUE,''),
('Metropolitan at Village at Leesburg','6 - Passed','Washington, DC-MD-VA',335,NULL,328358,110000000,'2024-02-14','2024-02-06','2024-03-27','signed CA 2/8
$325K/unit --- $110M. 5.4% Cap in place.',TRUE,FALSE,''),
('Gables River Oaks','6 - Passed','Houston, TX',302,2014,238410,72000000,NULL,'2024-02-06','2024-03-06','coming soon
guidance is low $70’sMM here',FALSE,TRUE,''),
('Gables Wilton Park','6 - Passed','Fort Lauderdale-Hollywood, FL',145,2009,413793,60000000,'2024-03-05','2024-02-08','2024-03-06','all docs saved
target is $60mn. That includes the 19k of retail as well',FALSE,TRUE,''),
('Virage Luxury Apartments','6 - Passed','Houston, TX',372,2014,NULL,NULL,'2024-03-05','2024-02-06','2024-03-06','coming soon',FALSE,TRUE,''),
('Cortland Seventy Seven','6 - Passed','Charlotte-Gastonia-Rock Hill, NC-SC',340,1996,205000,69700000,'2024-02-13','2024-01-09','2024-02-26','all docs saved
Guiding to $205K/unit on this one which shakes out to ~5.5% trailing cap.',TRUE,TRUE,''),
('Village at Broadstone Station Apartments','6 - Passed','Raleigh-Durham-Chapel Hill, NC',300,2013,206666,62000000,'2024-02-14','2024-02-06','2024-02-26','all docs saved
~$62M or $207K/door here. 5.5 on T3, tax-adjusted for recently released 2024 reassessment',FALSE,TRUE,''),
('Park Place at Van Dorn','6 - Passed','Washington, DC-MD-VA',285,2002,368421,105000000,NULL,'2023-10-18','2024-02-06','all docs saved
Jay – guidance is $105MM+ which is a mid-5% cap on in-place. Great value-add and getting 9%+ on trade-outs. Let us know if you want to set up a tour.',TRUE,FALSE,''),
('Leo LoSo','6 - Passed','Charlotte-Gastonia-Rock Hill, NC-SC',284,2023,387323,110000000,NULL,'2023-12-13','2024-02-06','OM Saved

The owner will be going to market in Q1. There''s an assumable 40-year $55mm HUD loan at 2.89%. Construction is complete and final CO has been issued. 

Projected NOI is $5.6mm. 10 units have been leased 

Seller asking $110mm.',FALSE,TRUE,''),
('Phase 2: Washington Apartments','6 - Passed','Washington, DC-MD-VA',200,1978,300000,60000000,'2023-05-23','2023-04-25','2024-02-06','all docs saved

Guidance is ~$60M, which is ~5.30% in-place cap (tax adjusted).

 There’s an in-place loan you can assume - $32.5M in proceeds, 3.43% fixed, full term IO, matures 10/21/29.',TRUE,TRUE,''),
('Phase 3: Washington Apartments','6 - Passed','Washington, DC-MD-VA',200,1978,300000,60000000,'2023-05-23','2023-04-25','2024-02-06','all docs saved

Guidance is ~$60M, which is ~5.30% in-place cap (tax adjusted).

 There’s an in-place loan you can assume - $32.5M in proceeds, 3.43% fixed, full term IO, matures 10/21/29.',FALSE,TRUE,''),
('Fort Totten Square','6 - Passed','Washington, DC-MD-VA',345,2015,304347,105000000,NULL,'2023-10-24','2024-02-06','all docs saved
retail is included, $80M for the resi and $25M for the retail',FALSE,TRUE,''),
('Mount Vernon Flats at The Perimeter','6 - Passed','Atlanta, GA',412,1997,266990,110000000,NULL,'2024-01-09','2024-02-06','all docs saved
Pricing for Mount Vernon Place should be in the +/- $110 million range.   

This asset has one of the best value add stories we have witnessed in Atlanta.  The current owner is currently working on their second round of unit renovations, and achieving just under a $400 increases.  They have completed just under 90 units.  

The location benefits from a very low development pipeline, excellent demographics and schools.  The average unit size is 1,100 s.f, which fits well with the demographic.',FALSE,TRUE,''),
('The Lexington','6 - Passed','Washington, DC-MD-VA',72,2024,NULL,NULL,NULL,'2024-01-09','2024-02-06','all docs saved
fully vacant and entitled re-development opportunity, located in the heart of Capitol Hill. The Property will convey, fully permitted and approved for 72 multifamily units.',FALSE,TRUE,''),
('Meadows At Salem Run Senior Apartments','6 - Passed','Washington, DC-MD-VA',180,1997,122222,22000000,NULL,'2024-01-09','2024-02-06','all docs saved
Guidance is $22M --- $120k/unit. 
Assumable Financing
- FNMA Loan
- July 2021 start
- $14.64mm UPB
- 3.4% all-in rate
- I/O through June 2028
- 2036 maturity
The cap rates are usually pretty comparable to market. 

In this case, with the in-place debt at 3.4%, we would be in the same range: 5% in-place & 5.25% Y1.',FALSE,TRUE,''),
('Capitol Towers Condominiums','6 - Passed','Nashville, TN',172,1959,81395,14000000,'2024-02-14','2024-01-09','2024-02-06','signed CA 1.9
Thank you for your interest.  Initial guidance is +$80k per unit or +$14M.  Let us know what other questions we can answer.
172 condos and 6 retail spaces (42 condos owned individually), 79.3% controlling interest stake
Potential to redevelop if can gain full control',FALSE,TRUE,''),
('Circa at Fishhawk Ranch','6 - Passed','Tampa-St. Petersburg-Clearwater, FL',260,2015,NULL,NULL,'2024-02-08','2024-01-09','2024-02-06','all docs saved',FALSE,TRUE,''),
('Provenza at Old Peachtree','6 - Passed','Atlanta, GA',258,2013,242248,62500000,'2024-01-18','2023-12-13','2024-02-06','all docs saved

Pricing should be in the low to mid $60M range.  That is a mid-5% cap year one and well north of a 6% if you contemplate renovating the units/improving the common areas.  
 
Provenza is a really nice asset with plenty of renovation upside.  Rents in the submarket (across the street) are as much as $200 higher for newer assets.  
 
In addition, there is existing debt that can be assumed that matures in Feb 2026: 
•	Loan Amount: $32.8M
•	I/O till 2/29/2024
•	Rate: 4.44% 
•	Lender: AIG',FALSE,TRUE,''),
('Aspire Lenox Park Apartments','6 - Passed','Atlanta, GA',407,2000,233415,95000000,'2023-08-24','2023-07-25','2023-12-07','all docs saved

Guidance is around $235K per unit in the mid-$90M range. Pretty incredible basis for this quality product. About a 5.5% cap FY1. Part of the underwriting will need to adjust for expenses. Currently T-12 controllable expenses are $5,900/u --- pretty steep for a property that has no elevators, no concierge, no security patrols, and no need for crazy marketing given tight well-known submarket.

Fully renovated with nine foot ceilings throughout. Product built in 2000 – institutionally owned and maintained by Corebridge/Lincoln since 2014. Offer due date not set yet but probably the week of August 21st. OM will be available early next week.',TRUE,TRUE,''),
('Avalon at Foxhall','6 - Passed','Washington, DC-MD-VA',306,1982,408496,125000000,NULL,'2023-10-18','2023-12-07','all docs saved
In an effort to keep the good times rolling, we want to put another opportunity in front of you guys that we think you’ll find compelling and similar to CT Plaza - another super high-barrier to-entry location and limited outreach on behalf of AvalonBay, so we greatly appreciate your discretion. Please see attached for the OM and confi with additional information available. A quick summary follows:

 
off mkt from Brenden
$125M; mid-to-high 5% cap rate stabilizing mid-6%
306 units; built in 1982, so not rent controlled, with large units (967 SF)
AVB has maintained the asset very well including recent capital improvement projects to the exterior and garage that enable a common area and in-unit focused value add strategy
85% of the demographic is student but the property is operated as traditional MF providing flexibility – comprehensive interior unit renovation or conversion to student housing model
 

Please let us know if you have any questions and we can certainly give some additional context if you have time to connect in the next few days, but otherwise let’s get a time on the calendar for you to see it when back in the States. We expect this will be a fairly quick process with request for initial offers by the end of October and a PSA executed by Thanksgiving.',FALSE,TRUE,''),
('10X Living at Columbia Town Center','6 - Passed','Baltimore, MD',531,2001,282485,150000000,'2023-11-28','2023-08-30','2023-12-07','now officially on mkt with Newmark (pricing around 150M) NO OM YET 10.18

all docs saved (off mkt) Probably need an offer before we can tour and not sure I can get questions answered. Aim for $155m to $160m.
 
You pay our fee.  What do you think about 55bps.',TRUE,TRUE,''),
('Gables 12 Twenty One','6 - Passed','Washington, DC-MD-VA',132,2009,359848,47500000,'2023-11-30','2023-10-18','2023-12-07','no OM
upper 40Ms, 5.5 cap',FALSE,TRUE,''),
('Eastwood Village','6 - Passed','Atlanta, GA',360,2001,145000,52200000,'2023-11-28','2023-11-09','2023-12-07','all docs saved
part of kevin geiger''s harbor group two pack - loan assumption, value-add
Regarding EV, we expect to sell this property in the low to mid $50 mm range ($145K to $150K per unit) at around a 6.5% cap stabilized. 

Harbor owns and manages and has left plenty for the new investor to do in terms of adding value. Most importantly, you can buy it free and clear or subject to the existing financing (which makes more sense to me). The property includes a 3.77% amortizing Freddie loan at $37 mm and matures in July 2026. You could look at that as pretty inexpensive bridge financing!

Harbor has spent the last several months cleaning up the bad debt and that’s where a lot of the opportunity lies. Focus on the AR, the T12 can overstate the bad debt because it is accrued.',TRUE,TRUE,''),
('Peachtree Landing','6 - Passed','Atlanta, GA',220,2002,159090,35000000,'2023-11-29','2023-11-09','2023-12-07','all docs saved
part of kevin geiger''s harbor group two pack - loan assumption, value-add
Peachtree Landing is same seller, similar in-place financing. Harbor will sell these together or as one-offs. That one is around $35 mm with similar metrics. See attachment.',TRUE,TRUE,''),
('Lofts at Lakeview Apartments','6 - Passed','Raleigh-Durham-Chapel Hill, NC',352,2006,275568,97000000,'2023-12-06','2023-11-06','2023-12-07','all docs saved
We are targeting high $200s per unit, which is going to be somewhere north of $275k. There is a ton of renovation upside, and a lot of operational improvement that collectively make this a compelling investment.',FALSE,TRUE,'')
ON CONFLICT (name) DO NOTHING;

INSERT INTO deals (name,status,market,units,year_built,price_per_unit,purchase_price,bid_due_date,added,modified,comments,flagged,hot,broker) VALUES
('Thornberry Apartments','6 - Passed','Charlotte-Gastonia-Rock Hill, NC-SC',288,2000,164930,47500000,'2023-11-21','2023-10-24','2023-11-28','all docs saved
Initial pricing guidance is ~$165k-$170k/unit (upper $40Ms), representing a ~6% normalized in-place cap (tax and insurance adjusted).  Initial offers will be due mid-November.
 
Key Investment Highlights:
288 units 
Year Built: 2000
$1,445 | $1.49 SF in-place rents
 
•	LOW BASIS – Significant +30% Discount to Surface-Parked Garden Replacement Cost ($230Ks)
•	SUPPORTED VALUE-ADD – Renovate remaining 145 or 50% Classic Units (+$162 headroom to comp set avg; +$236 headroom to reach comp)
•	DESIREABLE SUBURBAN PRODUCT – Low-density, 3-story suburban garden, 9’ ceilings
•	INSTITUTIONALLY MAINTAINED – Significant CAPEX invested since 2020 to address deferred maintenance (roof replacement, exterior paint, pool deck, seal coat/stripe)
•	EDS & MEDS JOBS – University City & UC Research Park: a broadly diversified corporate jobs machine; Charlotte’s second largest employment hub
•	RETAIL EXPERIENCE – Proximate +1M SF of retail including multiple grocery-anchored centers (Harris Teeter, Trader Joes, Lidl)
•	CONNECTIVITY – I-77, I-85 and I-485; 5 minutes to LYNX Blue-Line Light Rail',FALSE,TRUE,''),
('810 Ninth Apartments','6 - Passed','Raleigh-Durham-Chapel Hill, NC',229,2016,358078,82000000,'2023-11-15','2023-10-24','2023-11-28','all docs saved
Pricing guidance is low-to-mid $80mm range (~$360k/unit), which is just above a 5% cap (going in-tax adjusted)– well below replacement costs! Reassessed taxes won’t be due until 1/1/26, so almost the first two years of the hold will be going in at a mid 5% yield!

High barriers-to-entry submarket with practically zero oncoming supply and a compelling mark-to-market story.',FALSE,TRUE,''),
('The Fitzroy at Lebanon','6 - Passed','Nashville, TN',240,2021,212500,51000000,'2023-11-15','2023-11-13','2023-11-28','all docs saved
Low 50mms range.',FALSE,TRUE,''),
('The Crescent at Fells Point by Windsor Apartments','6 - Passed','Baltimore, MD',252,2007,309523,78000000,'2023-10-25','2023-10-23','2023-11-28','all docs saved
-	Cut Off is $78.0M, and due Wed the 25th
-	Cap Rate on Aug Rent Roll and T-12 Expenses 6.4%
-	Owner ship has redone the roof, painted the hallways and new carpet throughout in the past 2 years',TRUE,TRUE,''),
('Spring Valley Apartments','6 - Passed','Washington, DC-MD-VA',28,1936,NULL,NULL,NULL,'2023-10-18','2023-11-09','OM saved',FALSE,TRUE,''),
('Woodmore Apartments','6 - Passed','Washington, DC-MD-VA',268,2022,328358,88000000,'2023-09-20','2023-08-21','2023-10-19','all docs saved
Moving target depending on capital markets but $88M is whisper. 

•	Fantastic Lease-Up Activity – 25 unit per month average lease-up since completion – currently 83% leased with no concessions;
•	Rental Upside - Ability to underwrite significant upside with rents still $150-$300 below nearby Class A comp set;
•	Entry Level Cap Rate - Priced at 6.2% cap rate in Year 1 with normalized in-place operating expenses; 
•	Best-In-Class Demographics - The submarket is one of the most affluent in the County; the average household income within a 1-mile radius of the Property is $140,000 and nearby homes have sold for more than $800,000;
•	Unparalleled Access to Retail - The Property is within walking distance to the Wegmans-anchored Woodmore Towne Centre, the 2nd most visited shopping center in the State of Maryland with 10.1 million visits per year.',TRUE,TRUE,''),
('Mayton Transfer Lofts','6 - Passed','Richmond-Petersburg, VA',223,2011,130044,29000000,NULL,'2023-10-18','2023-10-19','built 1911 reno 2011
Great basis for 2011 construction and attractive assumable debt. Here to talk it through. 
•	$29M PP
•	$130/Unit
•	6.0% on T3 Rev, T12 Exp, TA at 90% of PP with $100K credit to LTL based on positive trends at the Property. Was previously managed by mom & pop management company carried over from acquisition, now managed by BH for the past ~11 months. 
•	Assumable Debt:
o	4.32% Fixed
o	Fannie
o	Full-Term I/O through 7/1/28
o	UPB $13,975,000
o	Supplemental quote at $3,753,000
o	Blended interest rate of 5.14%
o	Blended LTV at ~62% of PP',FALSE,TRUE,''),
('The Kingson','6 - Passed','Washington, DC-MD-VA',240,2020,300000,72000000,NULL,'2023-10-03','2023-10-19','docs saved
In place debt at 2.35% (he thinks FTIO) 6 yrs remaining
Pricing low 70Ms, 5.25% T12 cap
Seller is Livcor',FALSE,TRUE,''),
('Preserve at Ridgeville','6 - Passed','Charleston-North Charleston, SC',240,2023,233333,56000000,'2023-11-01','2023-10-03','2023-10-19','all docs saved
I love this deal, it’s literally the only game in town for thousands of employees tied to Volvo and the Camp Hall campus which is in early innings build-out.
We expect pricing in the upper $50Ms as a loan assumption.',FALSE,TRUE,''),
('Park Pleasant Apartments','6 - Passed','Washington, DC-MD-VA',126,1960,182539,23000000,'2023-11-08','2023-10-03','2023-10-19','all docs saved
Pricing is probably going to be +/- $185k/ unit.
JS: mt pleasant, behing park regent, close to main street, could be worth touring',FALSE,TRUE,''),
('Marlowe Apartments','6 - Passed','Washington, DC-MD-VA',162,1987,339506,55000000,'2023-10-26','2023-10-03','2023-10-19','all docs saved
We are guiding to upper $50''s which is a high 4 cap on trailing/RE tax adjusted and is a stabilized 6.5% ROC.',FALSE,TRUE,''),
('Arbor Place','6 - Passed','Atlanta, GA',298,2004,194630,58000000,NULL,'2023-10-19','2023-10-19','all docs saved
Couple of things to note:  

1) This is a proven value-add with 70% of the units left to upgrade

2) There is a Tax Lock through 2024 which adds 30 bps to Year 1 cap

3) At mid $190,000/unit pricing:
     A) In-place cap is 5.7% (taxes at 85% per case studies & trended bad debt per A/R)      B) In-place cap is 6% with the Tax Lock. 

4) Upgrading units adds 100 BPS making the Yr 1-2 Yield 6.7% (not including Tax Lock)      and  7% with the Tax Lock

5) Offer date is 30 days out so we need tour in next 3-4 weeks.

I am at the property on Wednesday 10/25.  Can we set up tour? 

David',FALSE,TRUE,''),
('Cortland Canyon Creek','6 - Passed','Dallas-Fort Worth, TX',415,2020,250602,104000000,NULL,'2023-10-03','2023-10-18','all docs saved
Pricing guidance here is low-$250k/door, which equates to a 5% going-in cap (T3/T12 tax adj).',FALSE,TRUE,''),
('Bell Meadowmont Apartments','6 - Passed','Raleigh-Durham-Chapel Hill, NC',258,2001,320000,82560000,'2023-08-23','2023-07-19','2023-10-18','all docs saved
320k',TRUE,TRUE,''),
('Cortland at RTP','6 - Passed','Raleigh-Durham-Chapel Hill, NC',286,1998,220279,63000000,'2023-09-21','2023-08-16','2023-10-18','all docs saved
220k/unit',TRUE,TRUE,''),
('Presley Oaks','6 - Passed','Charlotte-Gastonia-Rock Hill, NC-SC',318,1996,227987,72500000,'2023-09-19','2023-08-30','2023-10-18','all docs saved
Initial pricing guidance is low-mid 70Ms (mid-$220Ks/unit), representing a low in-place 5% cap rate (tax and insurance adjusted). The offering includes attractive assumable financing and initial offers will be due September 19th.
 
Key Investment Highlights:
 
•	318 units built in 1996
•	LOAN ASSUMPTION – Attractive assumable debt with a current loan balance totaling $36.64M, an accretive 4.66% fixed interest rate, and a 12/1/2028 maturity date
•	LOW BASIS - Significant +20% Discount to Replacement Cost
•	VALUE ADD – Moderate VA upside in 100% of Unit Interiors & Amenities (+$235 headroom)
•	UNIQUE PRODUCT - Low-density (12 units/acre), 2/3-story suburban garden, institutionally owned since delivery
•	DIVERSIFIED JOBS - University City & UC Research Park: a broadly diversified corporate jobs machine; Charlotte’s second largest employment hub
•	RETAIL EXPERIENCE - Proximate to grocery-anchored Harris Teeter retail among a variety of other retail options
•	CONNECTIVITY – Fronting W W.T. Harris Boulevard and proximate to I-77, I-85 and I-485',TRUE,TRUE,''),
('Regency Johns Creek Walk','6 - Passed','Atlanta, GA',193,2012,310880,60000000,'2023-08-29','2023-08-03','2023-10-18','all docs saved

Pricing is $60M ($311K per unit), which is the following cap rate:

?	4.58% T3 / Tax Adjusted Cap Rate
?	5.52% Proforma Year 1 Cap Rate
?	6.98% Year 3 Post Renovation Cap Rate
 
The Regency at Johns Creek Walk is located in one of the top submarkets in Atlanta with the best demographics and highest barriers to entry.
 
There is strong organic headroom in the submarket in addition to upside through unit and amenity upgrades with the property’s 100% original finishes.
 
Also, the tax millage rate here in Fulton County/Johns Creek is 37% lower than in Fulton County/Atlanta—this equates to ~$21K per unit in value in tax savings.',TRUE,TRUE,''),
('Marquis Midtown District','6 - Passed','Atlanta, GA',372,2008,220430,82000000,'2023-08-29','2023-07-25','2023-10-18','all docs saved',TRUE,TRUE,''),
('Peyton Stakes','6 - Passed','Nashville, TN',249,2016,NULL,NULL,NULL,'2023-10-03','2023-10-18','coming soon',FALSE,TRUE,''),
('The Legends at ChampionsGate Apartments','6 - Passed','Lakeland-Winter Haven, FL',252,2002,222222,56000000,NULL,'2023-09-13','2023-10-18','all docs saved
Legends at ChampionsGate is a great property.  9 and 10’ ceilings, awesome high-growth location, strong value add play as most units have not been substantially renovated.  Pricing probably around $56-$58MM or so.  Let us know if you’d like to tour.',FALSE,TRUE,''),
('Tribute Verdae Apartment Homes','6 - Passed','Greenville-Spartanburg-Anderson, SC',268,2021,216417,58000000,NULL,'2023-09-13','2023-10-18','all docs saved
$215k-$225k',FALSE,TRUE,''),
('Crowne Club Apartments','6 - Passed','Greensboro--Winston-Salem--High Point, NC',250,1995,155000,38750000,NULL,'2023-09-06','2023-10-18','all docs saved

The property was built in the mid 1990’s and has been owned and managed by Crowne partners, the original developer, since being built. The property is performing very well at 98% occupancy and a higher NOI on the T-3 than the T-12. Guidance is $38,750,000. That is a 5.71% cap rate on T-3 revenues, T-12 expenses, with a $100,000 credit added to loss to lease and taxes normalized for the 2024 tax bill. With guidance at $155,000 per unit, Crowne Club is significantly lower than replacement costs in the area. 
 
187 of the units have been renovated and are achieving average premiums of $237. There is still significant value-add upside by adding premium finishes to all 63 classic units and the 187 renovated units. 124 units have vaulted ceilings above 9 feet, and the remaining units have 9-foot ceilings. Average unit size at the property is almost 1,100 SF.
 
The property is located just 5 to 10 minutes from major retailers like Whole Foods, Trader Joe’s, Target, Costco, and Walmart. It is also an ideal commuter location with immediate access to I-40 and U.S Route-421.',FALSE,TRUE,''),
('Tapestry Tyvola','6 - Passed','Charlotte-Gastonia-Rock Hill, NC-SC',297,2023,238215,70750000,NULL,'2023-10-03','2023-10-18','off market
Following up regarding Stonebridge’s potential appetite for pre-stab or near-stab new construction acquisitions.  Here is our quick look at Tapestry Tyvola, a surface-parked deal in Lower South End (LoSo).  Direct path of growth and top CLT submarket.

 

Tapestry Tyvola

297 Units

90% leased (as of September 2023)

 

Tapestry Tyvola - Google Maps

https://tapestrytyvola.com/

 

Key Assumptions / Notes

Model based on YR1 stabilized proforma
Using 3rd party resources to determine unit mix
Currently 90% leased
Spot Rental Rate GPR ($1,679 or $2.17) from Axiometrics
CBRE assumes 1 month lease-up concessions to account for LoSo supply pipeline
NER growth = 3.0%, 3.1%, 3.1%, 3.5% thereafter
Taxes = Stabilized FMV @ 86% of PP
Debt = Agency 10 YR execution upon stabilization
 

Curious to hear how you’d view pursuit of this asset. We think there may be a window to approach the Seller/Developer off-market.',FALSE,TRUE,''),
('Camden Peachtree City Apartments','6 - Passed','Atlanta, GA',399,2001,300751,120000000,NULL,'2023-10-03','2023-10-18','all docs saved
Institutionally Owned/Main Asset:

Built in 2001 by Summit Properties (merged with Camden in 2004)
Annual capital preservation invested ~$1,500 per unit.
 

RARE Peachtree City Opportunity:

Only SIX assets in entire city
22 YEARS since last asset built; Camden Peachtree City
One of TWO assets built after 2000
LAST completely unrenovated asset
 

100% Renovation Remains

NO interior upgrades completed – 100% classic | CARPET throughout |Laminate countertops
Opportunity for amenity improvements – expanding fitness center & enhancing outdoor spaces
 

Pricing Guidance

$300K per unit
5.50% in-place cap (T3/T12 - adj taxes)',FALSE,TRUE,''),
('The Cottages at Ridge Pointe','6 - Passed','Athens, GA',216,2020,310185,67000000,NULL,'2023-09-13','2023-10-18','all docs saved
Strike price: $310,000 per unit, which is well below replacement cost
Cap rate: >5.5% in year 1, with Axio forecasting 6.7% rent growth (we didn’t underwrite this).
In-place income: $96,268
Cleaned-up rent roll and well-managed future lease expirations
Reduction in AR from $112,000 earlier this year to $6,000 today',FALSE,TRUE,''),
('Off Market Lynchburg Portfolio','6 - Passed','Lynchburg, VA',789,2015,234474,185000000,NULL,'2023-09-06','2023-10-18','all docs saved
Off Mkt Portfolio (all called Gables) near Liberty University in Lychburg/Forest VA area (from W&D/Scott Doyle)

I’m working with a seller of four-property portfolio in Lynchburg, VA, consisting of 789 units and pricing guidance of $185M (breakdown below).

 

The portfolio has been meticulously well kept and maintained by the original builder, with rents are increasing across the board. There is also room for rental increases based on the area''s population growth and comparable properties raising rents. 

 

The opportunity is strictly off-market and comes from a private seller, so there isn’t an OM, deal room or flyer. Additionally, seller is requiring the buyer pay all broker fees, so please take that into account in your underwriting.

 

If interested in underwriting, complete the attached CA to receive financials.

 

 

Name

Units

Vintage

Pricing Guidance

Price Per Door

Occupancy

Jefferson Commons

216

2010

$49,000,000

$226,852

96%

Spring Creek

253

2015

$60,000,000

$237,154

98%

Eleven 25

232

2019

$59,000,000

$254,310

89%

Cornerstone

88

2008

$17,000,000

$193,182

97%

789

2013

$185,000,000

$227,875

95%',FALSE,TRUE,''),
('Arrowood Villas','6 - Passed','Charlotte-Gastonia-Rock Hill, NC-SC',120,2000,145000,17400000,'2023-10-04','2023-09-06','2023-10-18','all docs saved

This 120-unit, 2001 vintage property is ideally located in South Charlotte, giving tenants immediate access to Class A retail, office, and entertainment options. Please see detail below and reach out with any questions once you’ve reviewed the OM and offering materials.  

 

Due Diligence Data Vault: 

Arrowood Villas (click link) 

Offering Memorandum
July T12
RR as of 8/22/23
Last 3yrs Loss/Runs
HUD Loan Docs / Regulatory Agreement
ESA Phase 1
2022 Tax Bill
Acquisition Debt Quote (attached)
 

Summary:

Arrowood Villas operates in conformance as a Low-Income Housing Tax Credit (LIHTC) project limiting 42% of the units to 60% AMI (Area Median Income) restrictions (50 affordable units). Participation in this affordable program ensures investors are acquiring a high-quality asset that meets the strenuous criteria to be eligible for tax credits through the project. Additionally, the 50 affordable rent restricted units trail the NCHFA Max Allowable Rent by an average of $412 per unit - depending on the floor plan; allowing the ability to immediately reduce loss-to-lease by raising rents to the Max Allowable. There are also 70 market rate units with below market rents in-place which provides investors with a tremendous amount of operational upside across the full unit mix.  

 

Pricing Guidance:

Low to mid $140K’s per door (±$17.4M range). Ownership will evaluate all offers, we encourage you to underwrite the asset and offer at the pricing that pencils for you. 

 

Call for Offers:

Wednesday, 10/4/23 

 

Property Tour Dates (48hr advanced notice Required): 

Week One:

Tuesday: August 29, 2023

Wednesday: August 30, 2023

 

Week Two:

Wednesday: September 6, 2023

Thursday: September 7, 2023

 

Week Three:

Tuesday: September 12, 2023

Wednesday: September 13, 2023

Thursday: September 14, 2023

 

Week Four:

Tuesday: September 26, 2023

Wednesday: September 27, 2023

Thursday: September 28, 2023

 

 

Investment Highlights  

Immediate Rent Growth Achievable as Affordable Rents are Significantly Below the Max Allowable  
Robust Value Add Opportunity on 70 Market Rate Units 
Operational Upside through Expense Reduction and Utility Reimbursement Opportunities  
Favorable Renter Demographics in Booming South Charlotte Submarket 
Proximity to Demand Drivers and Major Highways  
 

Matterport Virtual Walkthroughs  

1BD / 1BA: Floor Plans 

2BD / 2BA: Floor Plans 

3BD / 2BA: Floor Plans 

 

LURA / Affordability Requirements 

LURA Contract – Land Use Restrictive Covenants for Low-Income Housing Tax Credits

 

Start Year 

2000 

Initial Compliance Period End Date 

2015 

Extended Use Period End Date 

2030 

Restrictions 

42% of units at 60% AMI restricted 

LIHTC Income Limits for 2023 

 

Persons 

60% AMI 

1 Person 

$43,260

2 Person 

$49,440

3 Person 

$55,620

4 Person 

$61,800',FALSE,TRUE,''),
('The Standard at White House Apartments','6 - Passed','Nashville, TN',240,2015,216666,52000000,'2023-10-11','2023-10-03','2023-10-18','all docs saved
Pricing will be $215-220k per door.
JS: 35 min NE of downtown, rural location, probably not interesting',FALSE,TRUE,''),
('Project Juniper','6 - Passed','Charlotte-Gastonia-Rock Hill, NC-SC',984,2016,223577,220000000,'2023-10-25','2023-09-13','2023-10-18','docs saved, no OM 9/13
3 property portfolio, Charlotte (2015), Raleigh (2017), Lakeland (2017)
Guidance is low $220M, which is a low-mid 5% on T-3 NOI. The assets can be acquired either individually or as a portfolio, so a breakdown of pricing is below. 

•	2015 – 2017 vintage 
•	First generation value-add opportunity
•	Modern 9’ ceiling product
•	Limited competing supply
•	Attractive discount to replacement cost
•	Tangible job growth story (RTP/University Research Park/I-4 Logistics Corridor)
•	Guidance: 
o	Afton Ridge – High $70mm
o	Park Place – Low-to-Mid $70mm
o	Ariva – Low-to-Mid $70mm
o	Low-5% cap rate in-place / 5.75% untrended ROC / low $200 per SF',FALSE,TRUE,''),
('10X Wellington Club Apartments','6 - Passed','West Palm Beach-Boca Raton, FL',204,2012,284313,58000000,'2023-10-17','2023-09-13','2023-10-18','docs saved, no OM 9/13
target on this one is high $50mn range. $3mn is the vacant land parcel. Let me know if you need anything else. Thanks.',FALSE,TRUE,''),
('Gables Midtown','6 - Passed','Atlanta, GA',345,2009,275362,95000000,'2023-09-14','2023-08-02','2023-09-06','all docs saved

Better on The BeltLine:

Since its inception in 2012, the Eastside Beltline has outpaced Atlanta’s CRE rental growth rates in every sector:
60% over ATL office | 50% over ATL retail | 55% over ATL multi-housing
With the Montgomery Ferry extension JUST completed in JUNE 2023, Gables Midtown will now reap the benefits of The BeltLine
Gables Midtown is just starting to benefit from The BeltLine with additional projects including Portman’s redevelopment of Amsterdam Walk (1.5 miles south) and Amour Yards (1 mile north)
 

Untouched Institutional Asset:

Built and owned by Gables since 2009
Lightweight concrete and steel construction  
100% classic units – 20% below like-kind comps POST-renovation
Extensive amenity spaces – including rooftop in need of contemporary improvements/repurposing
 

Atlanta’s Oldest Intown Neighborhood:

Founded in 1837, Piedmont Heights boasts homes values of $1-2M
Most acclaimed school district within Intown Atlanta
Unmatched location next to the recently completed BeltLine and visibility/access to the I--85 Connector
Equidistant to Atlanta’s major job hubs in Buckhead & Midtown
 

+35% Discount to Replacement Cost:

Eight story | lightweight concrete & steel construction | 903 SF
Land: $37,500 + Hard: $340K + Soft: $65K =
$153M | $443K | $490PSF
 

Pricing Guidance:

Mid to high $90M | 5.57% YR1 cap | 6.5% Post Reno
Scheduling tours now | CLICK HERE to schedule
CFO TBD',TRUE,TRUE,''),
('Disctrict','6 - Passed','Washington, DC-MD-VA',125,2013,640000,80000000,NULL,'2023-08-10','2023-09-06','',TRUE,FALSE,''),
('District-Retail','6 - Passed','Washington, DC-MD-VA',125,2013,NULL,NULL,NULL,'2023-08-10','2023-09-06','FOR RETAIL T12 ONLY',FALSE,TRUE,''),
('Alister Columbia Portfolio','6 - Passed','Baltimore, MD',344,1987,232558,80000000,NULL,'2023-08-22','2023-08-29','coming soon
Alister Columbia (176 units built 1987) + Alister Columbia Town Center (168 units built 1984)
We’re targeting $80m or ~$234k per unit for the Alister Portfolio which shakes out to be a 5.65% cap rate on our proforma and operates to mid-teens returns.  There is a significant amount of upside in both deals both operationally and through a strategic value-add program that includes a kitchen & bathroom renovation as well as a core+ strategy in previously renovated units.  The owner has completed an extensive overhaul on the common area amenities so the focus will largely be on operations and in-unit renovations.  The current controllable operating expenses for both assets are ~$6,700 / unit versus comparable properties operating at ~$4,850 / unit.  Additionally, fully renovated units are achieving $250 premiums for full kitchen & bathroom renovations that include quartz or granite countertops, stainless steel appliances, etc.  There is a lot to like in this portfolio',FALSE,TRUE,''),
('The Bend at 4800','6 - Passed','Richmond-Petersburg, VA',248,2002,187500,46500000,NULL,'2023-08-24','2023-08-29','part of LIHTC portfolio
46-47M',TRUE,TRUE,''),
('Richmond LIHTC Portfolio','6 - Passed','Richmond-Petersburg, VA',624,1998,160256,100000000,NULL,'2023-08-21','2023-08-29','all docs saved
LIHTC portfolio, ~4% avg in-place debt, low 5 caps, ~2000 built
The Bend at 4800 | 46-47M
Clearfield | 22M-23M
Mattox Landing | 11-12M
Pinetree | 18-19M',FALSE,TRUE,''),
('Sligo House Apartment','6 - Passed','Washington, DC-MD-VA',107,1960,NULL,NULL,'2023-08-30','2023-07-24','2023-08-24','all docs saved
we looked at this back in 2018, looks like it did not trade?',FALSE,TRUE,''),
('Solamar Apartment Homes','6 - Passed','Orlando, FL',210,2023,323809,68000000,'2023-08-16','2023-07-24','2023-08-18','all docs saved

Initial guidance is ~$68MM which is roughly a 5.4% cap on Year 1 tax adjusted. Note – this does not account for the new ‘Live Local’ legislation that will allow for a tax abatement of roughly $562k in 2024 (and going forward), which increases the cap to ~6.2%. The per unit pricing at ~$325k/unit is also a discount to recent comps and single family alternatives in the immediate area.

The property began leasing in January of this year and is currently 75% leased (65% occupied) while steadily increasing rents by more than $120/month since inception. Despite these increases, rents are still well-below comparables in the market. The location is also in the heart of Orlando’s fastest growing pocket of Osceola County with Axios/Realpage rent projections exceeding 4.8% annually over the next five years.

Notes from 8/14:
now 89% leased
315-320k guidance
5.5 cap w/o tax abatement
need to look into tax abatement (for keeping units affordable, but 120% AMI or less is much less than in-place rents)
market seller so submit offer even if low (dev with mexican equity, needs to roll these proceeds into other deals)',TRUE,TRUE,''),
('Rutherford Station Apartments','6 - Passed','Bergen-Passaic',108,2006,462962,50000000,NULL,'2023-08-01','2023-08-17','all docs saved
$50M guidance.',FALSE,TRUE,''),
('Bridgewater Apartments','6 - Passed','Atlanta, GA',532,1991,205000,109060000,NULL,'2023-07-27','2023-08-17','',FALSE,TRUE,''),
('Loft One35 Apartments','6 - Passed','Charlotte-Gastonia-Rock Hill, NC-SC',298,2016,335570,100000000,NULL,'2023-08-16','2023-08-16','all docs saved

Guidance is around $100mm (low-to-mid $330K/unit). It’s a 4.8% on most recent rent roll (tax and insurance adjusted). Getting to a mid 5% untrended YOC.',FALSE,TRUE,''),
('Presley Uptown','6 - Passed','Charlotte-Gastonia-Rock Hill, NC-SC',230,2016,304347,70000000,'2023-08-09','2023-07-24','2023-08-16','all docs saved

We’re guiding in the $70M range (~$300K per unit) which is  $75K/unit below replacement cost. Offers are due August 9th.

The asset has extremely accretive assumable debt (3.25% full term IO) with 6+ years remaining and is located directly next door to one of the most transformational development’s in Charlotte’s history – The $1.5B Pearl Innovation District which will deliver 5,500 jobs across the medical and life sciences industries as well as a 4 year medical school with the first class beginning in 2024.

In addition, there is a large rent delta to newly delivered midrise competitors ($2.80 PSF) and an even larger delta to nearby high rise supply ($3.25 PSF). Midtown 205, a similar vintage asset in the submarket, is currently taking advantage of this headroom and is achieving $300 premiums on their renovations. The large rent runway coupled with a value-add look-to provides ample support for investors to grow rents substantially whether that be through a renovation program or by drafting off of the increased demand stemming from the new medical campus.',TRUE,TRUE,''),
('Westerly at Worldgate','6 - Passed','Washington, DC-MD-VA',320,1996,296875,95000000,NULL,'2023-04-20','2023-08-16','signed CA 4.20
95 mil, 5% Y1 cap (allegedly), should be fully mission based for agency debt…',FALSE,TRUE,''),
('ARIUM Brookhaven','6 - Passed','Atlanta, GA',230,2015,265217,61000000,'2023-08-16','2023-08-16','2023-08-16','all docs saved

Pricing is $61M-$63M ($265K-$274K per unit), which is the following cap rate:



4.61% T3 / Tax Adjusted Cap Rate
5.43% Proforma Year 1 Cap Rate
6.85% Year 3 Post Renovation Cap Rate
 

ARIUM Brookhaven is achieving 15% on new leases since the beginning of July 2023. Also, the property has proven out renovations and offers optionality for continued interior renovations with the ability to drive rents ~$145.',FALSE,TRUE,''),
('Cambridge at Hickory Hollow Apartments','6 - Passed','Nashville, TN',360,1997,194444,70000000,'2023-07-21','2023-06-29','2023-08-15','all docs saved
Cambridge should trade in the high-$60M to low-$70M range.  That’s +/- a 5.0% cap on most recent, in-place numbers.',FALSE,TRUE,''),
('The Adley Lakewood Ranch Waterside Apartments','6 - Passed','Sarasota-Bradenton, FL',299,2019,327759,98000000,NULL,'2023-07-05','2023-08-09','Initial pricing guidance is $98M, $328K/unit, and a 5% T1 adjusted cap rate.  This is beautiful 2019 4-story elevator serviced Davis product located in the heart of Lakewood Ranch, the #1 master-planned community in the country.   

In addition to the area''s $754K average home values, $156K average household income, and A rated schools, the Sarasota MSA just jumped to the #1 spot for quality of life in the state.',FALSE,TRUE,''),
('Cortland Mooresville','6 - Passed','',203,2017,251231,51000000,'2023-08-02','2023-07-05','2023-08-09','docs saved, no OM 7.21
$250’s per unit range which is just under a 5% cap on in-place numbers.
 
This deal sits in the top school district in the Charlotte MSA and 6th best in the state (https://www.niche.com/k12/d/mooresville-graded-school-district-nc/) and the micro location is fantastic because its walkable to a highly amenitized grocery anchored (Harris Teeter) retail complex.
 
The same developer as this deal (Davis) recently completed a nearby comp, The Parian, which is currently leasing up at rents $200 higher than Cortland Mooresville which provides some solid headroom for rent growth with a light value-add program. 
 
CFO is set for July 26th.',FALSE,TRUE,''),
('Botanic at Ingleside','6 - Passed','Charleston-North Charleston, SC',302,2021,254966,77000000,'2023-08-03','2023-07-25','2023-08-09','I think both of these are lev neutral and fit into size bucket 

Madison - $260k-$265k
Botanic - $255k-$260k 

Both below replacement cost / Botanic is  wayyyy below replacement cost

Both are Charleston County so lower taxes

Both have huge floorplans
Madison - 1,037 avg SF (but only 1s and  2s)
Botanic - 1,095 avg SF 

Great job profile and both but Botanic in the middle of jobs bullseye in market

Madison - arguably better demos / incomes but so much going on in Palmetto Commerce Park for Botanic where there is:
- new 1-26 interchange  - imminent 1/2 mile from property - huge for better acces
- proposed 550k sf town center at that interchange
- new 400 acre urban park just acquired by N CHS that will be adjacent to Botanic

Both are good',FALSE,TRUE,''),
('Avalon Mamaroneck','6 - Passed','New York, NY-NJ',229,1999,458515,105000000,'2023-08-09','2023-06-29','2023-08-09','all docs saved
105-110M
extensively renovated 2018
suburb of nyc, on the way to conn',FALSE,TRUE,''),
('The Haynes House Apartments','6 - Passed','Atlanta, GA',186,2015,295698,55000000,'2023-08-10','2023-08-01','2023-08-09','all docs saved

Guidance on Haynes House is $55M.  The quality of this podium asset and location are very high.  The property is ideally located at Peachtree Street and Peachtree Battle Avenue in the exclusive Haynes Manor neighborhood of Buckhead.  While the asset is stabilized and performing well, there is a logical, light amenity, and interior VA opportunity that helps you get to a 5.25-5.5% post renovation yield.  Additionally, at this basis you’re a 25%+ value relative to replacement cost in a submarket that has zero pipeline of comparable product planned or under construction. 

Housing in the neighborhood surrounding the asset is currently starting around $3M and goes up from there (two homes adjacent to the property currently listed for $5M).  Also, adjacent to the property along Peachtree, there are several new construction condominium assets (Graydon and Dillon) that have recently delivered or are currently under construction that are selling units for up to $1K+ PSF.  Across the street is Peachtree Battle shopping center which has numerous restaurants, boutiques, retailers, and a Publix grocery store.  We are also located 5 minutes from the Buckhead Village and 10 minutes from the heart of Midtown – providing easy access to employment, shopping, arts, and entertainment.',FALSE,TRUE,''),
('Madison at Harper Place','6 - Passed','Charleston-North Charleston, SC',186,2022,258064,48000000,'2023-08-10','2023-07-24','2023-08-09','all docs saved
$260k- $265k per unit (low 5 cap on broker PF)',FALSE,TRUE,''),
('Trails at Hunter Pointe','6 - Passed','Nashville, TN',216,2022,250000,54000000,'2023-08-01','2023-07-25','2023-08-01','all docs saved

Pricing guidance on Trails at Hunter Pointe is in the low to mid $250s/unit. Currently 90% pre-leased, the property is concluding its initial lease up and will be stabilized, with recent leases trending above market rents. Best sales comp (Bexley Parkstone – 2022 build, 240 units) sold for $358K/unit last year making this an attractive basis opportunity. 

 

For insurance we are UW $450/unit.

Built in 2022, Trails at Hunter Pointe is located in Gallatin, TN, a highly desirable submarket northeast of Nashville. Bolstered by Facebook Meta’s $1B investment in a new 800-acre data center, Gallatin has become a hotbed for growth and expansion outside of Nashville. 

The property is primed for organic rent increases, as market rents are below the comparable properties of similar vintage in the submarket. Due to the city of Gallatin’s strict zoning requirements making it difficult for new multifamily development, occupancy within the submarket is projected to remain at 96%+ over the next 10-years with strong rent growth trends as well. 

Looping in Donny and Daniel for any debt related questions.

Call for offers is set for Tuesday 8/1.',FALSE,TRUE,''),
('Orchard Meadows Apartment Homes','6 - Passed','Baltimore, MD',240,2012,270833,65000000,'2023-07-13','2023-06-29','2023-07-25','all docs saved
talked to Zach 7/5, guidance 270/unit, cap rate 5.6%, F&C or Loan Assump: 40M, 4.25% fixed, 5 Yr Term 1 Yr IO.
Phase 1 = 1998, Phase 2=2012
Guidance is $65M --- $270k/unit. (5.6% Cap T-90/T-12)',TRUE,TRUE,''),
('22 Caton','6 - Passed','New York, NY-NJ',73,2014,NULL,NULL,NULL,'2023-06-29','2023-07-24','JLL OM Greystar sent is saved

Hope all is well! We wanted to preview an attractive Core+ deal in Brooklyn with you as we look for opportunities that might be a fit. Based on feedback from Lyric, we think this could make sense given it’s on the smaller side. Returns here are compelling and it presents the opportunity to buy a quality asset with really strong cash flow out of the gate. The team is touring today with our management team and we’d be happy to preview the opportunity on a call if it makes sense and we can share additional information then. Below are some of the general return / deal guidelines and attached is the OM. Hope to connect on this or something else soon.
 
1)	Returns (10-year Hold):
a.	Year 1 / 10 Yr Cash on Cash: 6.18% / 6.70%
b.	ULIRR / LIRR: 8.71% / 12.29%
2)	Deal: 
a.	Units: 73 units
b.	Equity: $18M - $35M of equity depending on leverage
c.	Vintage: 2014
d.	Market Rate: 100%, 421-A through 2030
e.	Current Owner: Original developer, The Hudson Companies
f.	Location: Windsor Terrace, Brooklyn (Prospect Park adjacent)',FALSE,TRUE,''),
('Max on Morris','6 - Passed','Newark, NJ',85,2023,441176,37500000,NULL,'2023-06-29','2023-07-24','signed CA 6/29
CFO expected 3rd week in July
We think this trades in the upper $30M’s, maybe to $40M which is a 5.5% - 6.0% cap on Year 1 NOI (opened in Feb so there is no T12).  An update to our marketing materials is the average household incomes for residents in the property is $192k per household.
signed CA 6/29',FALSE,TRUE,''),
('Boulders Lakeview','6 - Passed','Richmond-Petersburg, VA',212,2023,278301,59000000,'2023-07-12','2023-06-29','2023-07-21','all docs saved

Guiding to $59M, $278k/unit which is a phenomenal basis for this product. Developer did not cut corners and paid great attention to detail.

Not sure how familiar you are with this pocket of Richmond (although I’m pretty sure you know it well), but this is in a really excellent pocket of Chesterfield. Sits in Boulders Office Park, great school district, and equidistant to downtown Richmond as well as new Lego facility (2k-3k jobs). Leasing has been almost too vast, averaging 8-12 units/week, so we just grew rents quite a bit and are executing well. Solving for 5.4 cap on year 1.',TRUE,FALSE,''),
('Cortland University City','6 - Passed','Charlotte-Gastonia-Rock Hill, NC-SC',372,2009,220430,82000000,NULL,'2023-07-05','2023-07-21','NEED TO SAVE DOCS
guidance is low-mid 80Ms, 220s/unit, trending to a FY1 low 5 cap',FALSE,TRUE,''),
('Worthing Place Apartments','6 - Passed','West Palm Beach-Boca Raton, FL',217,2010,599078,130000000,'2023-07-19','2023-06-29','2023-07-06','all docs saved
$130mn. $17mn is the retail value.',FALSE,TRUE,''),
('The PARQ at Cross Creek Luxury Apartment Homes','6 - Passed','Tampa-St. Petersburg-Clearwater, FL',297,2008,262626,78000000,'2023-07-21','2023-07-05','2023-07-06','signed CA 7.5
$78M, $263k per unit, low 5% T3 tax and insurance adjusted.',FALSE,TRUE,''),
('Arbors at Fair Lakes Apartments','6 - Passed','Washington, DC-MD-VA',282,1987,319148,90000000,'2023-06-14','2023-05-16','2023-07-05','no OM, other docs saved 5/16

Guidance is $90M which is ~5.00% on in place.',FALSE,TRUE,''),
('Curve 6100','6 - Passed','Washington, DC-MD-VA',136,2008,341911,46500000,'2023-07-12','2023-06-29','2023-07-05','all docs saved
talked to Zach 7.5, BAF 7/12, upd guid 44.5M, offers are 40-43M. 44.5M T3 cap ~5.4 per Zach, construction has started on landmark mall redev
$46.5M --- $340K/door. ~5% Cap in-place.',FALSE,TRUE,''),
('Legacy at Wakefield','6 - Passed','Raleigh-Durham-Chapel Hill, NC',369,2011,230352,85000000,'2023-05-17','2023-04-24','2023-07-05','all docs saved

$230s per unit, which is a low 5.00% Y1 cap without any value-add attributed to that cap. Adding in value-add, you are getting somewhere in the 5.25 to 5.50% range on Y1 depending on scope and downtime considerations.',FALSE,TRUE,''),
('Reed Row','6 - Passed','Washington, DC-MD-VA',132,2017,378787,50000000,'2023-05-25','2023-05-16','2023-06-29','all docs saved

Shooting for 50 MM – which is upper 4s cap but there is in place debt around 30 MM at just above 4% for 5 years full term IO which makes the cash on cash pretty attractive.',TRUE,TRUE,''),
('The Lyric Luxury Apartments','6 - Passed','New York, NY-NJ',285,2000,891228,254000000,NULL,'2023-02-27','2023-06-29','All docs saved
Greystar Equity Request - total deal size = 281M, 103M equity request (can be split with another LP)',TRUE,FALSE,''),
('AMLI on Maple','6 - Passed','Dallas-Fort Worth, TX',300,2012,233333,70000000,NULL,'2023-03-28','2023-06-29','all docs saved
Pricing guidance is low-$70mm (upper-$230k/door). Let me know if you’d like to hop on a call to chat through the opportunity in further detail.',TRUE,TRUE,''),
('Integra Lakes','6 - Passed','Orlando, FL',203,2017,260000,52780000,'2023-05-18','2023-04-12','2023-06-29','all docs saved
Guiding $260k per unit',TRUE,TRUE,''),
('The Colonel','6 - Passed','Washington, DC-MD-VA',70,2015,471428,33000000,NULL,'2023-04-24','2023-06-29','no OM or docs, signed CA 4/24
Regarding The Colonel, we’re targeting $33m or $388k per unit for the property which shakes out to be a 5.5% blended cap rate on our proforma. We''re positioning the property as a core+ opportunity where you can complete a light in unit renovation and achieve rental premiums of approximately $200 per unit rental premiums based on rental comps in the immediate submarket.  The property comprises 70 units with three retail bays that are fully occupied and also connects to Blagden Alley which is a great amenity for the building and residents.  There is lots to like about this deal both in location in Shaw and in product with tangible upside.',FALSE,TRUE,''),
('Columbia Uptown','6 - Passed','Washington, DC-MD-VA',90,1951,280000,25200000,NULL,'2023-04-25','2023-06-29','all docs saved
Pricing guidance is $25.2M',FALSE,TRUE,''),
('Huntington at King Farm Apartments','6 - Passed','Washington, DC-MD-VA',402,2000,335820,135000000,'2023-05-10','2023-04-06','2023-06-29','signed CA 4/6
guidance is around $135mm / 5.4% cap on RR over T12',FALSE,TRUE,''),
('Manor Six Forks','6 - Passed','Raleigh-Durham-Chapel Hill, NC',298,2010,248322,74000000,'2023-05-10','2023-04-06','2023-06-29','all docs saved
74mm
includes retail, looks like a good location, near TJ and Wegmans',FALSE,TRUE,''),
('Braxton at Woods Lake','6 - Passed','Greenville-Spartanburg-Anderson, SC',232,1997,180000,41760000,'2023-06-14','2023-05-16','2023-06-29','all docs saved

Guidance is $180k/unit which is an in-place 5% cap, tax adjusted and a 5.50% at today’s occupancy with normalized concessions. After completing the remaining value-add, the property will be north of a 6.75% cap in Year 3.

Ownership has completed a Class-A renovation on 134 units that are achieving up to $250 premiums. The in-place campaign can be continued on the remaining 101 unrenovated units to push rents $200+.

 The property benefits from a strong location just East of downtown boasting high average household incomes, great schools and proximity to major employers/economic drivers. The main exterior capex items ($847k+) including brand new roofs, conversion of unused amenity spaces and balcony/window replacements have been completed by current ownership, allowing the focus to be spent on the interiors and pushing rents in line with comparables.',FALSE,TRUE,''),
('Avere on the High Line Townhomes','6 - Passed','Denver-Boulder, CO',56,2022,660714,37000000,NULL,'2023-05-16','2023-06-29','all docs saved

We’re guiding to $37mm on AVERE, which we have at about a 5.15% cap on current rents and pro forma expenses of ~$10k/unit.',FALSE,TRUE,''),
('Olympus Hillwood','6 - Passed','Nashville, TN',354,2010,231638,82000000,'2023-05-18','2023-04-12','2023-06-29','all docs saved

Guidance is in the 82/83mm range.',FALSE,TRUE,''),
('63 Roebling Street','6 - Passed','New York, NY-NJ',54,2008,740740,40000000,NULL,'2023-05-16','2023-06-29','$40m+
We have been hired to sell 63 Roebling Street, a 54-unit multifamily building on the corner of N 8th and Roebling in North Williamsburg, Brooklyn. The Property’s 15-year 421a tax abatement is set to expire in June 2024, and with rents currently ~$51/RSF, there will be significant mark to market. There is also $26,040,000 in assumable debt at 3.41% with 10-years remaining, including IO payments until November 2024.',FALSE,TRUE,''),
('Cortland Cinco Ranch','6 - Passed','Houston, TX',186,2016,215053,40000000,'2023-06-01','2023-05-16','2023-06-29','coming soon

We think it will trade in the $40 million range, which is about a 5% cap.',FALSE,TRUE,''),
('NorthCity 6 Apartments','6 - Passed','Raleigh-Durham-Chapel Hill, NC',291,2009,235395,68500000,'2023-06-14','2023-05-16','2023-06-29','all docs saved

$235-240k/unit.',FALSE,TRUE,''),
('AVILA Apartments','6 - Passed','Orlando, FL',269,2022,350000,94150000,'2023-06-07','2023-05-16','2023-06-29','signed CA 5/16

here is around $350K per unit, which is a low 5% YR. 1, tax-adjusted cap rate.

This is an incredibly unique property as it is one of the only assets in Central Florida to offer 3-story buildings with elevator service, conditioned corridors and 10’ ceilings on the first and third floors. The property is highly amenitized, including a two-story integrated clubhouse and a massive pool/courtyard area between the main building and building 2. There is also a separate outdoor amenity area with grilling stations, cornhole and a putting green between buildings 2 and 3.

 This is located in Oviedo (consistently ranked one of the best cities to live in Florida, less than 15 minutes from UCF), which has affluent demos, great school and limited historical supply due to widespread opposition towards apartments from community officials and residents. Additionally, since the property is technically in unincorporated Seminole County, the millage rate is one of the lowest in the MSA, which is a $1,500-2,500 per unit savings on operating expenses compared to other',FALSE,TRUE,''),
('69 East 125th Street','6 - Passed','New York, NY-NJ',77,2017,448051,34500000,'2023-06-22','2023-05-16','2023-06-29','signed CA 5/16',FALSE,TRUE,''),
('501 Estates','6 - Passed','Raleigh-Durham-Chapel Hill, NC',270,2001,277777,75000000,'2023-06-01','2023-05-15','2023-06-29','all docs saved

We’re guiding ~$75M ($277K per unit) which is approximately a 5% cap on the T3. The OM will be available on the data site next week and CFO date is Wed May 24th.

 There is assumable debt with a supplemental already in place, ~$39M loan balance, ~4.5% blended rate, ~18 months remaining on the IO, ~5.5 years of term remaining (full loan details are available on the data site).

 This is a unique deal because the construction was way ahead of its time with 35% of the units being direct entrance townhomes or cottages. The site is low density (only 8 units/acre) with the largest floor plans in the market (1,170 average SF) and the property’s landscaping and tree canopy give it the feel of an established residential neighborhood rather than an apartment community. Ownership has meticulously maintained the asset and completed renovations on 169 of 270 (63%) of the units with a value add 1.0 program and also demolished the old tennis court and developed an immaculate standalone gym.

 The location along Hwy 15-501 means the asset is barbelled by Chapel Hill (6 miles) and Durham (5.5 miles). Given the direct access to both UNC-Chapel Hill and Duke University, the renter profile on-site consists mostly of Eds & Meds jobs, which tend to be highly sticky and stable (unlike tech). Due to the proximity to Duke University, there are a number of Duke graduate students (Duke Law, Duke Med, and Fuqua MBA’s) but there are not undergraduates from either university.',FALSE,TRUE,''),
('The Watson Apartments','6 - Passed','Tampa-St. Petersburg-Clearwater, FL',205,2023,270731,55500000,'2023-03-28','2023-03-15','2023-06-23','all docs saved
Initial guidance is in the low $60Ms, low $300Ks/unit, which is a Yr.1 5% tax adjusted cap rate.
ZMR Capital sent around at a $55.5M PP',TRUE,TRUE,''),
('Riverside Station Apartments','6 - Passed','Washington, DC-MD-VA',304,2005,287828,87500000,'2022-09-29','2022-09-06','2023-05-16','all docs saved
Pricing is $85-$90M, which is around a 4% cap. Nice upside on this one!',FALSE,TRUE,''),
('Cantare at Indian Lake Village Apartments','6 - Passed','Nashville, TN',206,2013,266990,55000000,'2023-04-26','2023-03-29','2023-05-09','all docs saved
Guidance is mid $50mm which equates to ~ a 5% cap rate on in place tax adjusted numbers.  We haven’t set a CFO date yet but will likely be end of April. 

Blackstone is the owner and has maintained the asset in fantastic shape. Still, there is opportunity, as evidenced in area comps, to do some light value add improvements and push rents.

The property is located within Indian Lake Village, a large master planned mixed use development, which affords it so many conveniences and amenities not seen in many suburban deals.

Hendersonville is one of the more supply-constrained submarkets in our MSA and as a result, Costar/Axio project future rent growth in the area to be one of the top performers for Nashville.',TRUE,TRUE,''),
('Mission Lofts','6 - Passed','Washington, DC-MD-VA',156,2021,320512,50000000,'2023-04-18','2023-03-20','2023-05-09','all docs saved
Low 50 MM which ends up being about a 5.5 cap',FALSE,TRUE,''),
('Odyssey Rental Homes','6 - Passed','Fort Myers-Cape Coral, FL',129,2023,403100,52000000,NULL,'2023-04-06','2023-04-28','all docs saved

Thank you for reaching out.   We are expecting Odyssey to price out in the $52mm ($400,000/unit) to $54mm ($420,000 per unit) range, which yields a year 1 cap rate of 5.53% to 5.20% based on market rents (ie, the rents they are signing leases at now), taxes at 80%, and insurance at $1,750 per unit.   These are conservative assumption since we are not including rent growth while the market is projected to see 5.3% rent growth; you could do a cost segregation for real estate tax purposes keeping the re-assessment below 70%; and we have a recent soft quote for insurance at $1,300 to $1,500.    When you flip these switches, the cap rate is 6%+.

I would strongly recommend you come see this asset to appreciate why residents prefer this property over competing garden-style properties in the area.',FALSE,TRUE,''),
('Alta West Gray','6 - Passed','Houston, TX',166,2018,219879,36500000,NULL,'2023-04-03','2023-04-28','all docs saved
~220k a unit',FALSE,TRUE,''),
('Main and Stone','6 - Passed','Greenville-Spartanburg-Anderson, SC',293,2017,242320,71000000,NULL,'2023-04-06','2023-04-28','all docs saved

Guidance is low $240s per unit, ~$71M, which includes both the residential and ground floor retail (21k sf, 96% occupied).  It’s a great downtown location with incredible visibility along Main St & Stone Ave.  The product is a mix of conventional mid-rise buildings, townhomes, and direct entry flats.  We tilt towards a smaller average floorplan (782 sf) which by design makes it the cheapest rents in the submarket.  ~$1,450 in-place trending to the low $1,500s on recent leases.  There is real upside in the operations and light value-add across interiors/commons areas.  I think buyers will generally fall in one of two buckets: (a) Core-Plus strategies who like the mark-to-market opportunity with light value-add upside to continue closing the $250+ rental gap to competing product downtown or (b) Value-Add focused buyers who will execute a slightly higher capex spend to further drive rents while still maintaining a real discount to downtown. 

It''s third party managed by Lincoln who has had 4 PMs in the last 12 months.  Last summer, they were pushing renewals on some of the higher LtL residents and got caught in seasonality and occupancy dipped to the mid-80s.  That trend has reversed (8 new leases last week) and we’re low 90s leased today.  My guess is a buyer will be stepping into a +/- 95% rent roll by the time of closing.',FALSE,TRUE,''),
('Sterling Town Center','6 - Passed','Raleigh-Durham-Chapel Hill, NC',339,2012,241887,82000000,NULL,'2023-04-24','2023-04-25','coming soon

Guidance is low-to-mid $80M range, mid-$240’sK/unit, high 4% cap range with assumable HUD 223f loan at 3.45% base rate. 

The HUD could be pre-paid now (6% of UPB or $2M) as well if that’s not your preference to assume, and the property qualifies for mission business via Fannie/Freddie.

Although, 150 bps of positive leverage the day you close feels worth the additional administrative with HUD, while maintaining a market exit at the end of your hold period as the HUD loan pre-pay will be nil after a 5-year hold. Takes a lot of pressure off of growing out of negative leverage.

Feels like you must stomach 100 bps of negative leverage in the free and clear world even today to buy in Carolinas and we don’t see that changing materially in the near term.',FALSE,TRUE,''),
('Advenir at Gateway Lakes','6 - Passed','Sarasota-Bradenton, FL',358,1996,300279,107500000,'2023-04-12','2023-03-22','2023-04-11','all docs saved
$107.5M, $300k per unit, which is a 5.16% Feb T3 tax adjusted cap rate, and a 5.38% Feb T1 tax adjusted. 
T12 insurance is $1000 per unit.  Adjusting to $1500 per unit, it’s a 5.00% T3 and 5.22% T1.',TRUE,TRUE,''),
('Spoke Apartments','6 - Passed','Atlanta, GA',224,2018,254464,57000000,'2023-04-11','2023-03-20','2023-04-11','all docs saved
Pricing is $57-60M ($254-268K Per Unit), which is a Year 1 Cap of 5.00%-5.30% tax adjusted or a 5.30-5.60% all cash yield with in-place tax abatement. Also, below are a few highlights on the opportunity:
?	Attractive Agency Fixed rate loan with 3.97% interest rate and 3.5 years of IO remaining. LTV would be 55-60%.
?	Unique Mark to Market Opportunity during hold, to eliminate 15% affordability component and own 100% market rate asset.
?	Ideally located in highly desirable East Atlanta neighborhood of Edgewood/Candler Park, with convenient access to BeltLine trails.
?	Basis is significantly below today’s replacement cost',TRUE,TRUE,''),
('Grandewood Pointe Apartments','6 - Passed','Orlando, FL',306,2005,294117,90000000,'2023-04-11','2023-04-03','2023-04-11','Differentiated, low-density product (& largest floorplans) within infill submarket w/ strong fundamentals and limited pipeline
Balanced job drivers (Darden, Lockheed, Ritz, JW, Shingle Creek) and easy regional access via Turnpike & 528
Upside – only 15% renovation complete, averaging $455 pop post-reno, includes organic growth
Loan Assumption (available in DD room) – 2.98% rate, 3 years IO, 8 years term left, 50% LTV/Supplemental quote up to 65%

guidance is low $90Ms.',FALSE,TRUE,''),
('The Edison Apartments','6 - Passed','Fort Myers-Cape Coral, FL',327,2020,324159,106000000,NULL,'2023-03-21','2023-04-11','Coming Soon
Target pricing will be $325k per unit. We plan to formally hit the market in the next few weeks.',FALSE,TRUE,''),
('Broadstone Locklyn','6 - Passed','West Palm Beach-Boca Raton, FL',280,2022,392857,110000000,NULL,'2023-03-20','2023-04-11','coming soon
110mm',FALSE,TRUE,''),
('Motiva','6 - Passed','Washington, DC-MD-VA',354,2022,338983,120000000,NULL,'2023-04-03','2023-04-03','all docs saved
Pricing is around $120M.',FALSE,TRUE,''),
('Progress Village Apartments','6 - Passed','Tampa-St. Petersburg-Clearwater, FL',291,2020,302405,88000000,'2023-04-04','2023-02-28','2023-04-03','all docs saved
assumable debt at 3.74%, good location in Tampa',TRUE,TRUE,''),
('Cortland Delray Station','6 - Passed','West Palm Beach-Boca Raton, FL',284,2017,362676,103000000,'2023-03-30','2023-02-28','2023-04-03','signed CA 3/6
Guidance is $103m - $3652k/unit, about 5% cap adjusted for taxes and insurance. Great on-site demographics of about $170k avg HH income. It’s being offered free & clear and offers will be due in about a month. This is a beautiful property, originally built by Wood Partners in 2017. It boasts top of the line interior finishes and is only a few blocks from the infamous Downtown Delray / Atlantic Avenue. The property features a robust amenity package, including putting green,24/7fitness center, yoga studio, resident clubhouse with game room, electric charging stations and more. This property is also seeing about 20% trade outs on new leases and 10% on renewals over the past 90 days. One thing to note here is 25% of the units must be rented to households that make less than 140% AMI. However, the max rents based on 140% AMI is still well above full market rent. The City of Delray Beach is requiring WFH for all new construction deals since 2012 and will be in-place for at least 40 years.',TRUE,TRUE,''),
('SkylineATL','6 - Passed','Atlanta, GA',225,2009,240000,54000000,'2023-03-17','2023-02-21','2023-04-03','all docs saved
Management turn-around underway:
•	Previous management company accumulated a $500K+ AR problem, ignored a massive tenant Airbnb problem, and generally failed in every aspect of the asset''s management
•	Greystar took over management 4Q2022
•	Greystar now has visibility into evictions for the last 22 delinquent tenants and has increased occupancy to high 80s  
•	Next owner will have a stabilizing asset at closing
 
Massive, $100K+/unit discount to replacement cost:
•	Large average unit size (1,023 SF with 43% 2BRs), partial 1 & 2-story podium with 5-story stick would cost $350K+/unit to reproduce today
•	Pricing guidance is ~30% below replacement cost
Pricing: 
$240K/unit; $244/SF
5.3% YR1 cap',TRUE,TRUE,''),
('Heritage at Shaw Station','6 - Passed','Washington, DC-MD-VA',71,1980,197183,14000000,NULL,'2023-02-16','2023-03-21','13-15M',TRUE,TRUE,''),
('Legacy West End','6 - Passed','Washington, DC-MD-VA',198,2018,656565,130000000,'2023-04-04','2023-02-16','2023-03-21','all docs saved
"for pricing, we’re offering guidance of $130/$135M, which works out to a 4.6% T1/T12 cap rate (5.05% Year 1)."',TRUE,TRUE,''),
('The Reserve at Eisenhower Apartments','6 - Passed','Washington, DC-MD-VA',226,2002,376106,85000000,'2023-04-04','2023-02-27','2023-03-21','all docs saved
We’re offering guidance of $85M ($376,106/unit, $373/RSF), which works out to a 4.71% T3/T12 cap rate.',FALSE,TRUE,''),
('The Guthrie North Gulch','6 - Passed','Nashville, TN',271,2018,369003,100000000,'2023-03-30','2023-03-08','2023-03-21','all docs saved
Guidance here is $100-105MM, likely more like 100 than 105 I am afraid',FALSE,TRUE,'')
ON CONFLICT (name) DO NOTHING;

INSERT INTO deals (name,status,market,units,year_built,price_per_unit,purchase_price,bid_due_date,added,modified,comments,flagged,hot,broker) VALUES
('One Plantation Apartments','6 - Passed','Fort Lauderdale-Hollywood, FL',321,2013,311526,100000000,NULL,'2023-03-20','2023-03-21','signed CA 3/20
100mm',FALSE,TRUE,''),
('Arwen Vista Apartments','6 - Passed','Charlotte-Gastonia-Rock Hill, NC-SC',296,2010,236486,70000000,NULL,'2023-03-14','2023-03-21','no OM 3/14 (coming out next week)
Pricing guidance is low $70Ms (mid-to-upper $230s/u), which translates to a high 4% in-place tax-adjusted cap rate. 

Property Summary:
•         Arwen Vista Website ? Google Map Location
•         296 units built in 2010; 1,087 SF avg unit size; all walk-up buildings, some with tuck-under garages 
•         $1,388 ? $1.28 psf in-place rents; 98.3% current occupancy
 
Capital History / Value-Add Upside:
•         Institutionally owned and managed with significant capital spent 2021-2022 (~$1.1M) to modernize all amenities and exterior paint; the amenities are best-in-class for the submarket
•         Opportunity to deploy revenue-generating capital to enhance interior finishes across 100% of units
•         There is ~$200 of headroom to the few remaining unrenovated comps in the submarket and +$380 of headroom to the newest comps in the submarket
•         The post-reno basis represents a discount to replacement cost for product that will rival new construction yet at a rental rate discount

OM will be ready next week, but the Document Center is now available.  Let’s plan to touch base after you’ve had a chance to dig in.',FALSE,TRUE,''),
('Villas at Riversong','6 - Passed','Charlotte-Gastonia-Rock Hill, NC-SC',188,2023,NULL,NULL,NULL,'2023-02-21','2023-03-20','OM Saved
Development Equity Request from CBRE - 15.6M equity check for 188 unit townhome portion

Excited to share the first of our team’s equity opportunities coming down the pipeline in 2023. This one with Longbranch. Nate and I look forward to discussing after you’ve had a chance to review.  

 

CBRE is pleased to share the Equity Capitalization Request on behalf of Longbranch Development for the ground-up development of Villas at Riversong, a BTR/Towhome community located in Charlotte, NC.

 

Longbranch is currently under contract to purchase 101-acres of vacant, forested, developable land strategically located alongside the Catawba River where they have received zoning approval and entitlements for up to 810 residential units. Land closing is scheduled for May 2023. As currently planned, the development will consist of +/- 188 paired-villas units located on 26.5 acres, an additional 366-unit garden-style community, and a 215-unit townhome community on the remaining 74.5 acres.

 

Longbranch will fund a minority GP portion of the required equity for development of the Villas and the entire land takedown and is seeking a LP JV Equity partner to fund the remaining equity with the ability to close by May 2023. This LP partner will ultimately be investing in the paired-villas portion of the Project via a ~$15.6MM equity check and partnering with Longbranch for a short-term land carry until a multifamily development group is identified to purchase and perform on the Garden phase of the project. At this stage a multifamily buyer has been identified for the Garden phase with negotiations on-going.

 

Longbranch Development focuses on the development and investment of residential communities on the first ring of dynamic metropolitan areas and select secondary markets through the Mid Atlantic, Southeast, and Florida. As a team they have delivered 750 rental townhomes to date across 6+ communities, plus an additional 2,200 multifamily and townhomes in process currently.',FALSE,TRUE,''),
('Avalon Columbia Pike','6 - Passed','Washington, DC-MD-VA',269,2009,416356,112000000,'2023-03-15','2023-02-27','2023-03-20','all docs saved
we’re offering guidance of $112M (5.15% T3/T12 cap rate)
JS: looks like good location, near Amazon, ANC, Army Navy etc.',FALSE,TRUE,''),
('Collection 14','6 - Passed','Washington, DC-MD-VA',233,2021,665236,155000000,NULL,'2023-02-21','2023-03-14','all docs saved - Marthas table development - 233 apts + retail',FALSE,TRUE,''),
('584-Unit NW DC Portfolio','6 - Passed','Washington, DC-MD-VA',584,NULL,385273,225000000,NULL,'2023-02-21','2023-03-14','all docs saved
$225MM for the portfolio and yes the portfolio can be broken up, but it is ideal to be sold to one purchaser.',FALSE,TRUE,''),
('260 Water Street','6 - Passed','New York, NY-NJ',26,NULL,913461,23750000,NULL,'2023-01-24','2023-03-14','all docs saved
OM shows in-place on 5.35 but t12 shows 3.7',FALSE,TRUE,''),
('The Elm','6 - Passed','Washington, DC-MD-VA',456,2021,625000,285000000,'2023-02-16','2023-01-23','2023-03-14','all docs saved
Shooting for 280-290 MM which is a 4.8-4.9 cap and about 615k a door.  Obviously a fantastic piece of RE and execution.  We know there is upside in the rents due to lease up and what they are getting on the trade outs',FALSE,TRUE,''),
('Advenir at Biscayne Shores','6 - Passed','Miami, FL',240,2014,350000,84000000,NULL,'2023-01-23','2023-02-28','all docs saved
target is $350k per unit',FALSE,TRUE,''),
('Rivers Bend','6 - Passed','New York, NY-NJ',179,1963,558659,100000000,NULL,'2023-02-21','2023-02-28','All docs saved
Off mkt equity request from Greystar, 75M equity check, upper east side nyc, in unit and common area value-add',FALSE,TRUE,''),
('Azola Avery Centre','6 - Passed','Austin-San Marcos, TX',359,2022,248489,89207749,NULL,'2022-04-19','2023-02-28','ZOM development deal, next to Texas A&M Health Center in Round Rock (Avery Centre master planned community)',FALSE,TRUE,''),
('The Apartments at Brayden','6 - Passed','Charlotte-Gastonia-Rock Hill, NC-SC',332,2016,210843,70000000,'2023-02-09','2023-01-30','2023-02-28','all docs saved
Current ownership has renovated 71 units achieving a $175 premium with a partial reno scope: lowered granite countertops, modern ceiling fans, updated pendant lighting, LED bath lighting, LED ceiling lighting, updated shower bar and shower head, updated kitchen faucet, and kitchen backsplash. Based on current rent levels compared to the comps, Brayden provides the opportunity to implement an enhanced renovation program throughout 100% of the units, especially given the limited supply pipeline in Ft. Mill (partially due to the $12k/u impact fee for new multifamily construction). 
 
Pricing guidance is ~$70M, or $210k/u, which translates to a high 4% cap in-place (mid-4% tax adjusted), trending to an FY1 5% tax adjusted cap rate.
 
As mentioned, initial offers will be due on Thursday, February 9th.',TRUE,TRUE,''),
('The Asher Apartments','6 - Passed','Washington, DC-MD-VA',206,2012,388349,80000000,'2023-02-22','2023-01-23','2023-02-28','all docs saved
We are guiding to $80M+ which is below replacement cost at $388K per door / $467 per SF.  This is an upper 4s T-3 with normalized op ex and north of a 5 on proforma.  The asset has existing debt at 60-65% LTV at 3.11% for the next three years which is IO and a total of a 7 years of term left.',TRUE,TRUE,''),
('The Shay','6 - Passed','Washington, DC-MD-VA',245,2015,448979,110000000,NULL,'2022-06-15','2023-02-22','docs saved, no OM 6/15
Guidance is ~$110M range, which is ~$450k/unit',TRUE,TRUE,''),
('Midtown at Camp Springs','6 - Passed','Washington, DC-MD-VA',291,2009,309278,90000000,NULL,'2022-04-12','2023-01-23','all docs saved
98M ish about a 4.7% in place
back on market, can buy for $90M which is a 5% cap on T3',TRUE,FALSE,''),
('Del Ray Central Apartments','6 - Passed','Washington, DC-MD-VA',141,2010,407801,57500000,'2022-09-29','2022-08-25','2023-01-23','docs saved, no OM 9/6

Guidance is high $50s - $60mm
$425/unit & $500/SF
4% cap on in place RE Tax Adjusted
5.0% in year 3 after light value-add (they’ve done 7 units)
141 units + 2,670 SF of retail (south block smoothie) 

There is existing debt +/- $27 MM at 3.69% IO for another 7 years if it helps you. Also, the affordable units convert to market in 2029',TRUE,TRUE,''),
('Glenwood at Grant Park','6 - Passed','Atlanta, GA',216,2016,312500,67500000,'2022-11-01','2022-09-13','2023-01-23','all docs saved
Pricing is in the High $60M range.  Glenwood at Grant Park includes a tax abatement with 5 years remaining after 2022.  This helps drive yield to mid 4% year one. Lease trade outs continue to be strong.',FALSE,TRUE,''),
('Liberty Warehouse Apartments','6 - Passed','Raleigh-Durham-Chapel Hill, NC',247,2017,445344,110000000,'2022-11-02','2022-10-05','2023-01-23','all docs saved
Both deals 110M
timing - CFO, 3rd or 4th of Oct, close early 2023
Liberty:
24k sf retail, food hall (majority ~15k sf) and chicken & waffles place, coffee shop
Value-add - no island or movable island, maybe add build in island to some units',FALSE,TRUE,''),
('The Reserve at Ellis Crossing Apartments','6 - Passed','Raleigh-Durham-Chapel Hill, NC',336,2016,327380,110000000,'2022-11-02','2022-10-05','2023-01-23','all docs saved
Both deals 110M, depends on taxes - 2025 reassessment, recent leasing no reassessment close to 5 cap, full reassessment 4.5
The Reserve:
near term opening of Publix
north edge of RTP, off 885 (new road connecting rtp to durham)
Hallie, overbuilt in terms of amenities etc.
Duck Pond owns both of these deals, family office out of new york, maintain their properties well - Greystar manages both of these
selling to recycle capital for development
purchased both directly from developer
Value Add, repurpose large/wasted amenity space, upper floors still have carpet, new lighting, backsplash, hardware, #1 maint item are faucets, versace glaze cabinets
timing - CFO, 3rd or 4th of Oct, close early 2023',FALSE,TRUE,''),
('Capitol Rose','6 - Passed','Washington, DC-MD-VA',158,2023,759493,120000000,'2022-11-08','2022-10-05','2023-01-23','all docs saved
We’re offering guidance of $120M ($759k/unit), which works out to a 4.3% Year 1 cap rate.',FALSE,TRUE,''),
('The Landings at Long Lake','6 - Passed','Lakeland-Winter Haven, FL',241,2006,203319,49000000,NULL,'2022-10-27','2023-01-23','all docs saved
49M',FALSE,TRUE,''),
('Providence Court','6 - Passed','Charlotte-Gastonia-Rock Hill, NC-SC',420,1996,270000,113400000,'2022-11-16','2022-10-24','2023-01-23','docs saved, no OM 10.24
270/unit, 245/ft',FALSE,TRUE,''),
('Colonial Village','6 - Passed','Washington, DC-MD-VA',149,1969,134228,20000000,NULL,'2022-11-10','2023-01-23','all docs saved
from Bret Thompson, sending to 10 groups, company is liquidating / must sell (MidCity Portfolio)',TRUE,FALSE,''),
('The Rushmore Apartments','6 - Passed','Washington, DC-MD-VA',117,2022,NULL,NULL,NULL,'2022-11-18','2023-01-23','All docs saved 
Off Mkt from Greysteel, 215/unit, "As the property was just recently stabilized, the trailing revenue numbers are not reflective of the current operations. 45 years left on the ground lease with a lease-holder 49-year option at FMV. Annual CPI increases"',TRUE,TRUE,''),
('The Winterfield at Midlothian','6 - Passed','Richmond-Petersburg, VA',238,2019,260504,62000000,'2022-12-06','2022-11-10','2023-01-23','all docs saved 
talked to Drew White 11/9, see email post call, good location / story but have to move rents 12% in year 1 to get to 5 cap.  HUD loan at high 3s to assume.
open to pre-emptive offers',FALSE,TRUE,''),
('Sweetwater Vista','6 - Passed','Atlanta, GA',300,2022,265000,79500000,'2022-10-19','2022-09-19','2022-10-24','docs saved, no OM 9/19

Thanks for your interest.  This is the first time in a decade where we’ve offered new construction at Replacement Cost of $265,000/unit. The property is fully leased so loan proceeds are maximized, and unlike most development deals, there’s immediate rental upside providing positive leverage within 6-months of ownership.   

Please note 46% of loss-to-lease burns off by buyer closing in December 2022, meaning going-in cap increases 25 bps during marketing. You should view the going-in cap rate based on a December 2022 close. The remaining loss-to-lease burns off in the first 6-months of new ownership, boosting yield again by another 30 bps.  

I think Douglasville will surprise you. Demographically it’s equivalent to Lawrenceville, Buford or Suwannee.  Unlike these locations, Douglasville has had only 8 properties built in 20-years due to water-sewer constraints and zoning moratoriums. This is the first property built in 10-years.  

Last, the micro-location is unique as it abuts the 2500-acre Sweetwater State Park, a distinctive advantage and major attraction for residents of the property.',FALSE,TRUE,''),
('Highland Park at Northlake','6 - Passed','Charlotte-Gastonia-Rock Hill, NC-SC',240,2014,250000,60000000,'2022-10-20','2022-10-05','2022-10-24','docs saved, no OM 10/5
need to confirm price with John',FALSE,TRUE,''),
('Dakota Mill Creek','6 - Passed','Atlanta, GA',259,2001,NULL,NULL,NULL,'2022-09-19','2022-10-24','all docs saved',FALSE,TRUE,''),
('Cherokee Summit Apartments','6 - Passed','Atlanta, GA',272,2000,NULL,NULL,NULL,'2022-09-19','2022-10-24','all docs saved',FALSE,TRUE,''),
('Edwards Mill Townhomes and Apartments','6 - Passed','Raleigh-Durham-Chapel Hill, NC',220,1984,NULL,NULL,NULL,'2022-09-13','2022-10-24','all docs saved
162 TH + 58 GN Units',FALSE,TRUE,''),
('The Village at Lake Lily Apartments','6 - Passed','Orlando, FL',455,2010,340659,155000000,NULL,'2022-09-13','2022-10-24','all docs saved
talked to Jubeen 9/13 - sounds like a great location, near ZOM office, very nice retail and residential nearby (close to nice part of Winter Park), built by PGIM/Morgan and still owned by PGIM, fully original units and common areas/amenities, 155M, ~340/unit (good basis), 3.2 cap in place tax adj, nice unit size and floorplans',FALSE,TRUE,''),
('Solaire at Coconut Creek Apartments','6 - Passed','Fort Lauderdale-Hollywood, FL',270,2014,385000,103950000,'2022-09-15','2022-08-23','2022-10-24','all docs saved
managed by ZRS since 2015, Darren sent to Will
target is $385k per unit. Cap is 3.7%.',TRUE,TRUE,''),
('1430 W','6 - Passed','Washington, DC-MD-VA',43,2000,302325,13000000,NULL,'2022-02-15','2022-10-13','',TRUE,TRUE,''),
('Middlebrooke Apartments','6 - Passed','Washington, DC-MD-VA',84,1962,280000,23520000,NULL,'2022-09-13','2022-10-05','all docs saved',FALSE,TRUE,''),
('Eighty Two Hundred','6 - Passed','Washington, DC-MD-VA',245,1967,270000,66150000,NULL,'2022-09-13','2022-10-05','all docs saved
includes 2 leased storefronts (1,465 sf) and one corporate office (8,500 sf)',FALSE,TRUE,''),
('Alden Landing Apartment Homes','6 - Passed','Houston, TX',292,1998,NULL,NULL,'2022-10-04','2022-09-13','2022-10-05','all docs saved',FALSE,TRUE,''),
('Waterleaf at Neely Ferry Apartments','6 - Passed','Greenville-Spartanburg-Anderson, SC',384,2020,NULL,NULL,'2022-10-05','2022-09-12','2022-10-05','all docs saved

Waterleaf is located in one of Greenville’s most desirable suburbs, the community is adjacent to grocery-anchored retail and walkable to both a highly ranked elementary school and new planned grocery-anchored shopping. Along the with the location, the construction quality and features are attracting and retaining a very strong resident base, with incomes averaging close to ~$100K across the property, and phenomenal rent growth coming out of lease-up (13%+ new lease rate increases over RR average and ~23% new lease trade-outs in July)

 Pricing guidance is in the high $250Ks to ~$260K per unit, which translates to a solid mid 4% cap FY1, trending quickly to a 5%+.  It sizes well for an agency pre or near-stab take out and should appeal to life cos as well with stabilization rapidly approaching.',FALSE,TRUE,''),
('Downtown 360','6 - Passed','Salt Lake City-Ogden, UT',151,2017,304635,46000000,'2022-09-29','2022-09-12','2022-10-05','all docs saved

Downtown 360 is surrounded by strong employment opportunities and the very best of entertainment and retail shopping that Downtown Salt Lake City has to offer. The property is extremely walkable with several restaurants and access to public transportation nearby. This is a rare opportunity to purchase a quality, core-plus, Class A asset in the robust Salt Lake Market.

Pricing guidance for Downtown 360 is $46,000,000 which is a 4.2% cap rate on the T3 with the T12 expenses including a $250 per unit reserve.  In-place rents are 8.5% below market. Increasing overall rents by a modest 6%, collapsing loss to lease and initiating property renovations on 1/3 of the units will yield a minimum average rent premium of $147/unit generating a year 1 cap rate of 4.8%, tax adjusted.  There is real potential to push rents further increasing yields.  Owners are market sellers seeking to close before year-end.',FALSE,TRUE,''),
('Instrata Pentagon City','6 - Passed','Washington, DC-MD-VA',325,2002,550000,178750000,NULL,'2022-09-06','2022-10-05','all docs saved
Guidance is around $178.75mm / $550kpu',FALSE,TRUE,''),
('The Brunswick','6 - Passed','Atlanta, GA',193,2020,347150,67000000,NULL,'2022-08-16','2022-10-05','all docs saved
(OM tax calc suggests 67M PP)

Pricing is $67-70M ($347-363k/unit), which is a ~4.53% cap rate based on recent leases – inclusive of a 25-year tax freeze, which eliminates reassessment risk until 2046.

The Brunswick has a truly irreplaceable location within Atlanta’s “Infill Arc” featuring both urban and suburban attributes along with short commutes to several of the city’s largest job centers.

Ideally positioned in Norcross, which (per Axiometerics) has the highest projected rent growth in the Atlanta MSA; equaling +33% over the next four years. The property is adjacent to a 4-acre city park and new library as well as just steps away from 30+ restaurants, breweries, boutique shops, and other lifestyle destinations.

The Offering Memorandum will be available next week, and Call for Offers will likely be mid-September; however, the seller will be responsive to preemptive offers.',FALSE,TRUE,''),
('Huntington at King Farm Apartments','6 - Passed','Washington, DC-MD-VA',434,2000,311059,135000000,'2022-10-06','2022-09-06','2022-10-03','all docs saved
Huntington at King Farm will be around $135mm, which is around a 4.9% on 8/9 RR + June T12',FALSE,TRUE,''),
('3801 Connecticut Avenue','6 - Passed','Washington, DC-MD-VA',307,1963,293159,90000000,NULL,'2022-07-01','2022-09-07','all docs saved
"whisper is 90M"',FALSE,TRUE,''),
('Braxton at Woods Lake','6 - Passed','Greenville-Spartanburg-Anderson, SC',232,1997,NULL,NULL,'2022-08-23','2022-08-16','2022-08-31','all docs saved',FALSE,TRUE,''),
('Millennium Apartment Homes','6 - Passed','Greenville-Spartanburg-Anderson, SC',305,2008,215000,65575000,'2022-06-02','2022-06-03','2022-08-16','all docs saved
Millennium – Greenville, SC,  Offers due June 2nd
•	305-unit garden asset
•	built in 2008 
•	owned by Millburn & Company based in Salt Lake City. 
•	The property has been institutionally maintained for the last 9 years, previously owned by KBS Legacy REIT.
 
The differentiated offering presents renters with a suburban build-to-rent-style living experience, with every unit having direct first floor entry, low density living amid an expansive 33-acre site and 79 tuck-under, detached garages. Current ownership has implemented preservation style upgrades to 85 units (28% of unit mix) that are achieving $125 rent premiums over classic units. Additionally, classic units trail Downtown Greenville comps by $1,025 and top suburban assets by $390 on average, leaving a true value opportunity for the next owner on all units.
 
Millennium is in the heart of Greenville’s innovation employment district, along I-85 and Laurens Rd, and is 5-minutes from both a Whole Foods Market and Trader Joes.
  
Guidance:
•	$215k/unit; 3.30% T3/T12 tax-adjusted cap rate 4.6% year one cap (on our proforma)',TRUE,FALSE,''),
('13|U','6 - Passed','Washington, DC-MD-VA',129,2017,NULL,NULL,NULL,'2022-06-14','2022-08-16','',TRUE,TRUE,''),
('Hacienda Village Co-Op Inc','6 - Passed','Orlando, FL',447,NULL,NULL,NULL,NULL,'2022-04-20','2022-08-16','Off Mkt MHC Req for Equity, Ground Lease?  Docs Saved',FALSE,TRUE,''),
('The Lincoln Apartments','6 - Passed','Raleigh-Durham-Chapel Hill, NC',224,2015,357142,80000000,'2022-06-01','2022-05-03','2022-08-16','all docs saved
We are guiding to $80m featuring attractive assumable debt with positive leverage.',FALSE,TRUE,''),
('Solaire Wheaton','6 - Passed','Washington, DC-MD-VA',232,2014,293103,68000000,NULL,'2022-05-17','2022-08-16','docs saved, no OM 5/17
The Property sits on the redline metro in Wheaton, MD providing excellent connectivity to all major DC employment hubs. The submarket has very little new supply (100 units) delivering in the near term and is supported by an ideal renter demographic and favorable third party rent growth projections (9% projection 2022, 4% YOY through 2026).
-	232 unit well amenitized mid-rise built in 2014
-	Average unit size 804 SF with 25% 2BR units
-	Below grade parking 254 spaces 
-	Mid 90’s occupancy with spread between adjacent comparable properties 
-	Offered below replacement cost
-	Loan assumption opportunity if desirable',FALSE,TRUE,''),
('Montfair at the Woodlands Apartments','6 - Passed','Houston, TX',310,2008,NULL,NULL,NULL,'2022-05-17','2022-08-16','all docs saved',FALSE,TRUE,''),
('Arbor Steele Creek','6 - Passed','Charlotte-Gastonia-Rock Hill, NC-SC',384,2004,232421,89250000,'2022-06-02','2022-05-03','2022-08-16','all docs saved',FALSE,TRUE,''),
('Peachtree Park Apartments','6 - Passed','Atlanta, GA',303,NULL,NULL,NULL,NULL,'2022-05-27','2022-08-16','',TRUE,TRUE,''),
('Park East Apartments','6 - Passed','Washington, DC-MD-VA',88,1962,286931,25250000,'2022-06-08','2022-04-20','2022-08-16','all docs saved
Low 160 MM
$110M – Argonne
$27.25M – Harvard Village
$25.25M – Park East',FALSE,TRUE,''),
('Harvard Village','6 - Passed','Washington, DC-MD-VA',85,1940,320588,27250000,'2022-06-08','2022-04-20','2022-08-16','all docs saved
Low 160 MM
$110M – Argonne
$27.25M – Harvard Village
$25.25M – Park East',FALSE,TRUE,''),
('The Argonne Apartments','6 - Passed','Washington, DC-MD-VA',276,1923,398550,110000000,'2022-06-08','2022-04-20','2022-08-16','all docs saved
Low 160 MM
$110M – Argonne
$27.25M – Harvard Village
$25.25M – Park East',FALSE,TRUE,''),
('Atlas LaVista Hills','6 - Passed','Atlanta, GA',399,2011,288220,115000000,'2022-06-07','2022-05-03','2022-08-16','all docs saved
Price guidance is in the $280ks/unit, which is $112-$115M, and an in-place tax-adjusted low 3% cap rate trending up to a mid-3%. Seller is RPM and CFO is TBD.
399-unit wrap property built by JLB in 2011 with brick/hardi exteriors
Convenient "ITP" location at I-285 and Northlake Parkway, proximate to Emory/CDC and Brookhaven''s Medical District
Next door, Emory Healthcare is redeveloping Northlake Mall for $20M and creating 1,600 new jobs
20% new lease trade-outs and 10% renewal increases 
Unit interiors are in original condition and ready to be modernized
Large amenity spaces and wide corridors primed for refreshing',FALSE,TRUE,''),
('Columbia Pointe Apartment Homes','6 - Passed','Baltimore, MD',325,1972,261538,85000000,NULL,'2022-06-15','2022-08-16','all docs saved
Guidance is around $85m',FALSE,TRUE,''),
('Tilden Hall','6 - Passed','Washington, DC-MD-VA',103,1923,300970,31000000,NULL,'2022-06-15','2022-08-16','all docs saved
+/- $31 million
2017 reno, conn ave between cleveland park and van ness',FALSE,TRUE,''),
('Traton Homes Atlanta Portfolio','6 - Passed','Atlanta, GA',287,2023,NULL,NULL,NULL,'2022-08-10','2022-08-16','',FALSE,TRUE,''),
('Cameron South Park','6 - Passed','Charlotte-Gastonia-Rock Hill, NC-SC',309,1985,300000,92700000,'2022-05-31','2022-05-17','2022-06-01','all docs saved
300k/unit',FALSE,TRUE,''),
('Linden at Del Ray','6 - Passed','Washington, DC-MD-VA',50,1961,270000,13500000,'2022-05-25','2022-05-03','2022-06-01','all docs saved
We’re offering guidance of $13.5M ($270k/unit), which works out to 5.0% Year 1 cap rate.',FALSE,TRUE,''),
('Boardwalk at Town Center Apartments','6 - Passed','Houston, TX',450,2006,NULL,NULL,'2022-05-24','2022-05-03','2022-05-25','all docs saved',FALSE,TRUE,''),
('Glenwood Park Lofts','6 - Passed','Atlanta, GA',236,2008,310000,73160000,'2022-05-24','2022-04-20','2022-05-25','all docs saved
Pricing guidance is $300-$320k/unit, which is a 4.50%-4.25% cap rate on Year 1 NOI.  
Glenwood Park Lofts is located in intown Atlanta near Glenwood Park and Grant Park with quick walkability to the Eastside BeltLine trail.  
The property is 98% leased and has achieved 21% rent growth on trade-outs of new leases over the last three months.   
The property also has extremely strong upgrade potential with all units currently having original finishes from 2008. 
The Offering Memorandum will be available at the end of next week and Call for Offers will likely be late May.',FALSE,TRUE,''),
('Whispering Pines','6 - Passed','Houston, TX',300,2002,280000,84000000,'2022-05-24','2022-05-03','2022-05-25','docs saved, no OM 5/3
Our original BOV was around $280k/unit, I’m not adjusting the number down because I’m getting no consensus on value from the market right now. This is great real estate being in the Woodlands Township and it’s one of the best management/value add stories I’ve seen in a long time. I have a market seller and I’m just telling people if they like it, submit.',FALSE,TRUE,''),
('Bell Fair Oaks Apartments','6 - Passed','Washington, DC-MD-VA',246,1989,345528,85000000,'2022-05-19','2022-04-20','2022-05-25','all docs saved
mid 80Ms',TRUE,TRUE,''),
('Winston House Apartments','6 - Passed','Washington, DC-MD-VA',140,1990,535714,75000000,'2022-05-19','2022-04-05','2022-05-19','all docs saved
CFO mid May
-	pricing is $75M
o	retail ~6M, 6.75 cap
o	multifamily ~492k/unit, mid 3s cap
?	4.3 cap on 2019 actuals
?	was hit hard during covid due to many GWU students moving out at once
o	I looked up the tax value and is 49M so taxes will go up ~215k / ~30bps impact on cap rate
o	Borger manages – came in about 1 yr ago
o	Owned by Irwin Edlavitch
?	HNW individual who has owned for 30 years and wants to step away, spend more time in FL etc.
o	45 renos done just before Borger came in
?	95 non-renos include various levels partials and non-renos
o	Great location and bones
?	118/140 have balconies, 700+ sf avg unit size, w/d in all units, gym, rooftop etc
o	No Rent Control due to 1990 build',FALSE,TRUE,''),
('The Brook Apartment Homes','6 - Passed','Charlotte-Gastonia-Rock Hill, NC-SC',162,1984,265432,43000000,'2022-05-19','2022-04-20','2022-05-19','coming soon
Initial pricing guidance for The Brook is in the low-$40Ms ($260ks/unit or $240s PSF).',FALSE,TRUE,''),
('Sailpointe at Lake Norman Apartment Homes','6 - Passed','Charlotte-Gastonia-Rock Hill, NC-SC',290,1994,320689,93000000,'2022-05-19','2022-04-20','2022-05-19','coming soon
Initial pricing guidance for Sailpointe is in the low-$90Ms, ~$320ks/unit. CFO will likely be the second week of May.',FALSE,TRUE,''),
('Tyler''s Ridge at Sandhills','6 - Passed','',216,2014,275462,59500000,'2022-05-17','2022-04-20','2022-05-19','all docs saved
Whisper pricing is in the mid 59m or mid 270s per door. We plan on a call to offers date the second week of May but strong offers will be considered early.',FALSE,TRUE,''),
('Meeder Flats by Watermark','6 - Passed','Pittsburgh, PA',276,2021,307971,85000000,'2022-05-12','2022-04-20','2022-05-19','all docs saved',FALSE,TRUE,''),
('Grayson Ridge Apartments','6 - Passed','Fort Worth, TX',240,1988,202083,48500000,'2022-05-12','2022-04-20','2022-05-19','signed CA 4/20
We are whispering $48-49 million and offers will be due in 4-5 weeks. Really strong location with significant frontage on I-820 – leasing velocity is robust, and the property is seeing elevated organic rent growth.',FALSE,TRUE,''),
('5115 Park Place','6 - Passed','Charlotte-Gastonia-Rock Hill, NC-SC',273,2016,340659,93000000,'2022-05-12','2022-04-20','2022-05-19','all docs saved
We are guiding to $340s a unit on 5115 Park Place.',FALSE,TRUE,''),
('Cortland Davis Park','6 - Passed','Raleigh-Durham-Chapel Hill, NC',287,2008,306620,88000000,'2022-05-11','2022-04-12','2022-05-19','all docs saved
88M+',FALSE,TRUE,''),
('The Colonel','6 - Passed','Washington, DC-MD-VA',73,2015,575342,42000000,'2021-10-13','2021-09-23','2022-05-16','All docs saved. OM saved.
-	Guidance is $42M (retail makes up roughly 7-8M)
o	Per Broker:  4.5% blended cap rate (MF~4%, Retail~5.25%) on T3 Income – T12 Exp Tax Adj
-	May Reigler is Manager
-	CFO 10/13
-	Retail is fully occupied and is all currently paying rent
o	There are retail concessions on the T12 that will look like they are attributable to MF but they are for retail',TRUE,TRUE,''),
('The Lowrie','6 - Passed','Charlotte-Gastonia-Rock Hill, NC-SC',245,2018,306122,75000000,'2022-05-10','2022-04-05','2022-05-11','docs saved, No OM 4/5',FALSE,TRUE,''),
('The Manor at Buckhead by ARIUM','6 - Passed','Atlanta, GA',301,2000,382059,115000000,'2022-05-09','2022-04-20','2022-05-11','all docs saved',FALSE,TRUE,''),
('Village on Memorial Townhomes','6 - Passed','Houston, TX',305,2004,295081,90000000,'2022-05-03','2022-03-31','2022-05-04','all docs saved
$90mm is guidance here Jay.  Appreciate you guys digging in.  ZRS is managing.  A+ real estate with build to forever hold type of developer.   Talk soon',FALSE,TRUE,''),
('Marq Midtown 205','6 - Passed','Charlotte-Gastonia-Rock Hill, NC-SC',261,2015,354406,92500000,'2022-05-03','2022-04-12','2022-05-03','all docs saved
Initial pricing guidance is low-to-mid $90Ms, ~$360s/u.  CFO will be mid-to-late April.',FALSE,TRUE,''),
('Reserve at Garden Lake','6 - Passed','Atlanta, GA',278,1991,190000,52820000,'2022-04-26','2022-04-12','2022-04-26','saved docs, no OM 4/12
Guidance is $185K to $195K per unit.
•	Current ownership has renovated 40 units that are achieving 48% premiums over classics
•	Renewals increase at ~20% while maintaining ~95% occupancy
•	$200 organic rent growth property wide
•	Exterior siding and paint project under way',FALSE,TRUE,''),
('Belle Haven Apartments','6 - Passed','Charlotte-Gastonia-Rock Hill, NC-SC',176,2014,NULL,NULL,'2022-04-18','2022-03-22','2022-04-20','all docs saved',FALSE,TRUE,''),
('Burrough''s Mill Apartments','6 - Passed','Philadelphia, PA-NJ',308,2003,NULL,NULL,NULL,'2022-03-31','2022-04-20','all docs saved',FALSE,TRUE,''),
('17 Barkley Apartments','6 - Passed','Washington, DC-MD-VA',315,2010,304761,96000000,NULL,'2022-03-31','2022-04-20','all docs saved
96M',FALSE,TRUE,''),
('Guardian Place II','6 - Passed','Richmond-Petersburg, VA',115,2000,117391,13500000,NULL,'2022-04-06','2022-04-20','All docs saved
Two Assets, GP I & GP II
We are targeting $27m which breaks out to ~$13.5m for each asset. These can be acquired together or separately so there is some flexibility depending on how you view each opportunity.  Guardian Place I is different in that the extended use period expires in 2023 so you can start phasing out affordability almost immediately.  Our analysis assumed an average market rent of $1,150 in Year 1, which is grown annually by submarket averages and is fully phased in by Year 3.This would equate to a 6.25% return on cost in Year 3 with the acquisition and estimated renovation cost.
 
Guardian Place II is more traditional with expiration of the extended use in 2029.~$13.5MM would equate to a 4.5% cap on our Year 1 and TTM.  Both assets are in a phenomenal location with newly constructed Class A multifamily and retail all around it.  At our value both offer a substantial discount on a per unit basis relative to where pricing would be if rents were market rate today.  In all this is a really exciting opportunity and that makes a lot of sense to dig in on.',TRUE,TRUE,''),
('Guardian Place I','6 - Passed','Richmond-Petersburg, VA',121,1994,111570,13500000,NULL,'2022-04-06','2022-04-20','All docs saved
Two Assets, GP I & GP II
We are targeting $27m which breaks out to ~$13.5m for each asset. These can be acquired together or separately so there is some flexibility depending on how you view each opportunity.  Guardian Place I is different in that the extended use period expires in 2023 so you can start phasing out affordability almost immediately.  Our analysis assumed an average market rent of $1,150 in Year 1, which is grown annually by submarket averages and is fully phased in by Year 3.This would equate to a 6.25% return on cost in Year 3 with the acquisition and estimated renovation cost.
 
Guardian Place II is more traditional with expiration of the extended use in 2029.~$13.5MM would equate to a 4.5% cap on our Year 1 and TTM.  Both assets are in a phenomenal location with newly constructed Class A multifamily and retail all around it.  At our value both offer a substantial discount on a per unit basis relative to where pricing would be if rents were market rate today.  In all this is a really exciting opportunity and that makes a lot of sense to dig in on.',TRUE,TRUE,''),
('Apartments at Westlight','6 - Passed','Washington, DC-MD-VA',93,2017,1021505,95000000,NULL,'2022-04-12','2022-04-19','all docs saved
-       they UW 100M, contract price is 93M, sounds like maybe 95M-100M could get it done    
-       they are actually representing the tenants here
-	contract purchaser is Hesta (Mexican REIT) which took under contract for 93M in 2019 when JLL had it on market
-	they offered 1k gift cards to tenants but tenants think they can do better
-	I will look into the numbers as it is apparently is a 4.25% year 1 cap at 100M (tax adj but with some inc growth and exp reductions (45% exp ratio as is))
-	very little rent growth over covid and apparently Sonnet on U St is getting higher rents, which is surprising if true',FALSE,TRUE,''),
('Foundry by the Park Townhomes and Apartments','6 - Passed','Baltimore, MD',592,1935,146959,87000000,NULL,'2022-03-23','2022-04-19','all docs saved
Guidance is $87M which is 4.7% on the Feb T12',FALSE,TRUE,''),
('Element at Stonebridge','6 - Passed','Richmond-Petersburg, VA',400,2016,262500,105000000,NULL,'2022-03-31','2022-04-19','all docs saved
Guidance is $105M. very strong look forward cap as their rents are much lower than market (including 70s vintage properties) and their operations aren’t maximized. It’s a great opportunity and low basis for where we are in the world.',FALSE,TRUE,''),
('South Bank (Mercer St 4 Port)','6 - Passed','Richmond-Petersburg, VA',150,2018,242106,36316000,NULL,'2022-03-23','2022-04-19','docs saved, no OM 3/29
Part of Mercer St 4 Portfolio',FALSE,TRUE,''),
('Star Lofts (Mercer St 4 Port)','6 - Passed','Richmond-Petersburg, VA',66,2013,165393,10916000,NULL,'2022-03-23','2022-04-19','docs saved, no OM 3/29
Part of Mercer St 4 Portfolio',FALSE,TRUE,''),
('Hopper Lofts (Mercer St 4 Port)','6 - Passed','Richmond-Petersburg, VA',139,2012,209539,29126000,NULL,'2022-03-23','2022-04-19','docs saved, no OM 3/29
Part of Mercer St 4 Portfolio',FALSE,TRUE,''),
('Perry Street Lofts (Mercer St 4 Port)','6 - Passed','Richmond-Petersburg, VA',148,2011,134202,19862000,NULL,'2022-03-23','2022-04-19','docs saved, no OM 3/29
Part of Mercer St 4 Portfolio',FALSE,TRUE,''),
('Valo Apartments','6 - Passed','Washington, DC-MD-VA',221,2018,452488,100000000,'2022-04-20','2022-03-15','2022-04-19','all docs saved
$100M, which is about $450K/unit and mid-3% year 1. Big discount to current replacement cost. Let me know if you want to tour Wednesday at 3 PM',FALSE,TRUE,''),
('Arbors at Carrollwood Apartments','6 - Passed','Tampa-St. Petersburg-Clearwater, FL',323,2001,300309,97000000,'2022-04-14','2022-03-15','2022-04-18','all docs saved
JS: ZOM built, broken condos 323/390, but good location, vintage, size etc.
$97M, 3.15% T3 trending to a 4%.  They are getting more than 20% increases on renewals with 65% retention and nearly 30% increases on new leases!  It''s a great basis at $300k per door for quality Zom product with 9''+ ceilings.  That''s below replacement cost in a very infill submarket with no new supply and a Whole Foods around the corner.',FALSE,TRUE,''),
('The Lex at Brier Creek','6 - Passed','Raleigh-Durham-Chapel Hill, NC',346,1999,295000,102070000,'2022-04-13','2022-03-15','2022-04-18','all docs saved',FALSE,TRUE,''),
('Solara Luxury Apartment Homes','6 - Passed','Orlando, FL',272,2014,295955,80500000,'2022-04-12','2022-03-15','2022-04-12','all docs saved
Ask is $80-81M which is high $290k''s per door and will be around a 3.25% on in place numbers at closing, adjusted for post sale taxes.',FALSE,TRUE,''),
('Aurea Station','6 - Passed','Charlotte-Gastonia-Rock Hill, NC-SC',384,1985,275000,105600000,'2022-04-12','2022-03-15','2022-04-12','all docs saved
Thanks for reaching out. We’re guiding mid $270s per unit which is a low 4% cap based on where recent leases are signing at 95% occupancy. The asset is currently underperforming the submarket, and there is a very large value-add play to close the $200+ gap to nearby properties who have recently undergone extensive renovations.  
 Offers are due April 12th. Let us know if you’d like to schedule a call or tour.',FALSE,TRUE,''),
('Enders Place at Baldwin Park Apartments','6 - Passed','Orlando, FL',220,2003,400000,88000000,'2022-04-07','2022-03-15','2022-04-12','all docs saved
$400k per unit',FALSE,TRUE,''),
('Summit Avent Ferry Apartments','6 - Passed','Raleigh-Durham-Chapel Hill, NC',222,1986,NULL,NULL,'2022-04-06','2022-03-01','2022-04-05','all docs saved',FALSE,TRUE,''),
('Infinity Apartments','6 - Passed','Washington, DC-MD-VA',227,1959,286343,65000000,NULL,'2022-03-23','2022-04-05','all docs saved
$65 mm | $286K per unit | 3.8% in-place and >5.0% pro forma post v/a – All 227 units can be improved generating $200 per unit premiums.  Free and clear and we will be in the market for 5 weeks or so from today.  No official date yes as we just launched.',FALSE,TRUE,''),
('Big Sky Flats','6 - Passed','Washington, DC-MD-VA',108,2022,370370,40000000,'2022-04-08','2022-03-01','2022-04-05','OM saved
We are expecting initial offers to come in probably +/-$40MM and upwards but it’s obviously way too early for us to know how high above that it might go if at all.',FALSE,TRUE,''),
('Overture Fair Ridge','6 - Passed','Washington, DC-MD-VA',200,2017,441250,88250000,'2022-04-07','2022-03-22','2022-04-05','all docs saved
JS: see active adult notes emailed to Will, part of Greystar/Carlyle Portfolio
95M per DC team, 88.25M based on pricing matrix from Seniors team',FALSE,TRUE,'')
ON CONFLICT (name) DO NOTHING;

INSERT INTO deals (name,status,market,units,year_built,price_per_unit,purchase_price,bid_due_date,added,modified,comments,flagged,hot,broker) VALUES
('Overture Cotswold','6 - Passed','Charlotte-Gastonia-Rock Hill, NC-SC',158,2018,403481,63750000,'2022-04-07','2022-03-22','2022-04-05','all docs saved
part of Greystar/Carlyle portfolio, see notes from call emailed to Will',FALSE,TRUE,''),
('Alexan East Atlanta Village Apartments','6 - Passed','Atlanta, GA',120,2016,300000,36000000,'2022-04-06','2022-03-07','2022-04-05','-"Guidance is mid $30Ms, or roughly $300k/unit. With the tax abatement, the year one yield is in the low to mid 4% range."',FALSE,TRUE,''),
('Links at Citiside','6 - Passed','Charlotte-Gastonia-Rock Hill, NC-SC',276,2001,220000,60720000,'2022-03-31','2022-03-01','2022-03-31','all docs saved
-"Guiding $215k - $225k/unit on this one."',FALSE,TRUE,''),
('Crescent Park Commons','6 - Passed','Greenville-Spartanburg-Anderson, SC',318,2009,215408,68500000,'2022-03-31','2022-02-23','2022-03-31','all docs saved
-"Guidance: $68.5M / $215k per unit / 4.25% Y1 cap (assumes renovating 30% of units in Y1)
CFO: TBD but likely 5 weeks in the market for a late March call for offers
Deal Highlights
•	Two Complimentary Phases – Phase 1 built by Wood Partners in 2009 (240 units) and Phase 2 built by Graycliff (seller) in 2020 is 78 units.
•	Phase 2 opened height of Covid in 2020 and management was very conservative with rents
•	Despite Phase 2 rents being $300-$400 below market, Phase 1 rents trail Phase 2 by $200
•	Value-Add – Phase 1 units are unrenovated and have a classic finish and feel. We are underwriting $9K per unit to bring up to Phase 2 finishes with $175/mo premium. Greystar’s Avana at Thornblade undergoing high-end quartz/stainless reno nearby
•	Washer Dryers – 82 Phase 1 units have a washer dryer installed and generating $50/mo. New owner can install in remaining 158 units to add $72k in annual income
•	Valet Trash – new owner has opportunity to add the service which is prevalent in the market
•	Operations - 99% occupied, 15-20% trade outs over 2021 leases, minimal delinquency, 56% retention rate
•	Replacement Cost – new proposed garden projects in Greenville at $260k per unit basis and moving forward
•	Location – sought-after local schools, quick access to BMW’s mega campus, and downtown Greer and Greenville in under 20 minutes, muted supply pipeline"
JS: location looks ok, NE Gville in Greer, 4.25 cap could be interesting if somewhat accurate',FALSE,TRUE,''),
('511 Queens Apartments','6 - Passed','Charlotte-Gastonia-Rock Hill, NC-SC',64,2018,414062,26500000,'2022-03-30','2022-03-01','2022-03-31','all docs saved
-"Targeting low 400''s per door. ~26-27M"',FALSE,TRUE,''),
('The Vive','6 - Passed','Charlotte-Gastonia-Rock Hill, NC-SC',312,2010,285256,89000000,'2022-03-30','2022-02-18','2022-03-31','all docs saved
-"Guiding $88-90m which is 3.6-3.7% in-place yield on current rent roll and trailing expenses. No tax adjustment here until year 3 due to county cycle"
JS: checks some boxes, but very far (NE) from CLT, do not know this area well',FALSE,TRUE,''),
('Parkside at Memorial Luxury Apartments','6 - Passed','Houston, TX',379,2015,250000,94750000,NULL,'2022-02-18','2022-03-29','all docs saved
-"$250k/unit for Parkside"',FALSE,TRUE,''),
('5 Oaks Apartments','6 - Passed','Houston, TX',228,2007,145000,33060000,NULL,'2022-02-18','2022-03-29','T12 & RR saved. No OM yet
-"$145k/unit for 5 Oaks"',FALSE,TRUE,''),
('The Meritage Apartments','6 - Passed','Houston, TX',240,2008,229166,55000000,NULL,'2022-03-07','2022-03-29','docs saved (no OM)
-"It’s a mid-rise deal developed in 2008 and will be a smaller deal size (~$55mm)"
Off Mkt / Eastdil',FALSE,TRUE,''),
('Tribeca','6 - Passed','Washington, DC-MD-VA',99,2021,666666,66000000,NULL,'2022-03-10','2022-03-29','saved docs from CBRE (no OM, RR, T12)
-"The building is 100% vacant, allowing for a TOPA-exempt transaction"
JS: NOMA, vacant no Topa',FALSE,TRUE,''),
('The Aria','6 - Passed','Washington, DC-MD-VA',60,2013,391666,23500000,NULL,'2022-02-14','2022-03-29','access requested
-"we’re offering guidance of $23.5mm"
JS: newer deal in DC / NOMA near REI, ok area still not great in parts
no CFO as of 2.28, Chris said probably  drawn out process until someone offers ~23.5M',TRUE,TRUE,''),
('Boathouse Apartments','6 - Passed','Washington, DC-MD-VA',250,2019,504000,126000000,NULL,'2022-03-15','2022-03-29','all docs saved
$126mm ($122mm resi and $4mm retail)
JS: weird location I do not think would be good for apartments, just wanted to make sure we saw it was on mkt',FALSE,TRUE,''),
('Grand Reserve Apartments','6 - Passed','Ocala, FL',263,2003,262357,69000000,'2022-03-29','2022-02-18','2022-03-29','All docs saved
We’ve been guiding to low to mid $260’s per door which we have pinned at around a 3.7% cap rate on year 1 numbers using conservative growth numbers.  Given other data points within the market and the physical product itself, we feel it’s a compelling value-add opportunity.
Since we last updated our valuation for ownership prior to launch, renewals have strengthened and are now trending in the mid 20% to over 30% on trade-outs organically without any value add initiative (in some cases $400+).  Additionally, while 90% of the units are in original finish, a handful that received upgrades prior to COVID are demanding an additional $300+ premium.  Glad to discuss in greater detail when you have a moment.  We’ve targeted March 29th as our bid date.',FALSE,TRUE,''),
('City View Towers','6 - Passed','Charlotte-Gastonia-Rock Hill, NC-SC',145,2004,465517,67500000,'2022-03-17','2022-02-14','2022-03-28','OM saved. no T12/RR
-"What makes this Uptown Charlotte opportunity unique is 1) the ability to add value via a conversion/renovation of the existing student building to market-rate multifamily and 2) ground-up development of the surface parking lot within a coveted UMUD zoning.  The UMUD zoning designation offers the flexibility to develop a variety of uses with no restrictions to density. We think the unit count can be increased from 145 units to approximately 272 conventional multifamily units. 

We included detailed conversion plans and massing studies in the Document Center to complement the OM. 

Initial offers will likely be due mid-March and we will send a Call for Offers Announcement as we get closer to the date. 

Pricing guidance is as follows based on the various components:
•	Existing Building = mid $50Ms
•	Developable Land Parcel (±1.35ac) = $12M-$14M (low $200/LSF)
•	Total = mid-upper $60Ms
It’s worth noting that the existing building and the surface parking lot will need to trade together and cannot be separated."
JS: good location, needs to go with approx. 1.35 acres (12-14M value) to develop - could be interesting JV with ZOM?',FALSE,TRUE,''),
('Berkshire Annapolis Bay','6 - Passed','Baltimore, MD',216,2003,310185,67000000,'2022-03-11','2022-02-14','2022-03-28','all docs saved
JS: need to research annapolis more from inv standpoint but checks some of our boxes
-"Some highlights…

Lease trade-outs averaged 20% in January and 14% in the second half of 2021.
The average unit size is over 950 square feet.
The Property features 80 units with attached garages.
It is a gated community.
There are only 7 other properties in Annapolis built after 2000."',TRUE,TRUE,''),
('Lofts at Uptown Altamonte','6 - Passed','Orlando, FL',324,2006,385802,125000000,NULL,'2022-03-15','2022-03-28','coming soon, financials saved, no OM 3/15',FALSE,TRUE,''),
('Harlow River Oaks','6 - Passed','Houston, TX',317,2014,235000,74495000,'2022-03-24','2022-02-14','2022-03-23','coming soon
-"$235k/unit range"
JS: nice location in RivOaks, newer deal prob not much VA',FALSE,TRUE,''),
('The Whitley Apartments','6 - Passed','Greenville-Spartanburg-Anderson, SC',250,1997,150000,37500000,'2022-03-22','2022-02-18','2022-03-22','all docs saved
-"Will go north of $150/door. Property is ripping"
JS: not in Gville, Central near Clemson, prob not interesting',FALSE,TRUE,''),
('Prose Memorial','6 - Passed','Houston, TX',352,2022,250000,88000000,'2022-03-22','2022-02-14','2022-03-22','coming soon
JS: on board in office, brand new just NW of Mem park',FALSE,TRUE,''),
('Montage at Embry Hills','6 - Passed','Atlanta, GA',225,2008,302222,68000000,'2022-03-21','2022-02-17','2022-03-22','coming soon
-"Price guidance is $68M+ or $300k+/unit with call for offers TBD but likely March 15th.  
 
•	2008 mid-rise wrap, non-conditioned corridors, 9'' and 10'' ceilings 
•	Situated along I-285 at Chamblee-Tucker Road next door to new 114,000 SF Kroger (largest in GA)
•	Less than 3 miles to $20M Northlake Mall redevelopment where Emory Healthcare is adding 1,600 jobs 
•	Owned by Liquid Capital, operated by First Communities 
•	Ownership recently spent $1M to paint exterior and corridors, and refresh amenities 
•	Renovated 30 units with quartz, stainless, etc. for $300+ premiums
•	87% of units remain in classic condition
•	New lease trade-outs up 27%+ "
JS: Embry Hills, location / nearby retail looks ok,just off 285, good vintage, 30 renos for 300+ per broker',FALSE,TRUE,''),
('Hawthorne Gates','6 - Passed','Atlanta, GA',164,1995,304878,50000000,'2022-03-17','2022-02-23','2022-03-22','T12 & RR saved. No OM yet
-"Price guidance is $50M+/-, low $300k/unit. 1995 construction, 164-unit property with 9’ ceilings and rare, oversized units (1,125 SF avg)
•	Recent leases in 1Q22 average $1,802/unit, 20%+ above the current rent roll average
•	All units primed for comprehensive value-add program - classic units have white appliances and laminate counters
•	Located along Peachtree-Dunwoody Rd. in Sandy Springs just east of GA 400
•	Submarket known for affluence, top schools, and stringent barriers to entry 
•	Walkable to North Springs MARTA station which provides rail access across Atlanta, including the Hartsfield-Jackson International Airport (<30 minutes)"
JS: sandy springs, value-add, see notes above
Owned by Eaton Vance who also has Five Oaks',FALSE,TRUE,''),
('Amberwood at Lochmere Apartments','6 - Passed','Raleigh-Durham-Chapel Hill, NC',340,1991,258823,88000000,'2022-03-17','2022-02-18','2022-03-22','all docs saved
-"-	Starting guide: mid/high $250Ks PU ($88M), or ~3.0% in-place, tax adjusted
-	340 2 and 3-story garden units in South Cary 
-	1991 (61% of units Phase I) / 1996 (39% Phase II)
-	Affordable avg $1,199 | $1.34/SF rents with +$385 of headroom to Audubon Parc
-	Best amenities in the comp set: pair of pools, bark parks, fitness centers, adjacent to Greenway
-	$1.7M capital spend T-24 (exterior paint, repave, clubhouse, leasing office, etc)
-	17% trade-outs in T-90 new leases (11.2% blended) with momentum
-	Proven +$220 premiums on 12% of units (Beach Upgrade; 35 in Phase I, 4 in Phase II) 
-	Enhancement potential across inherited Heavy (71%) and Light (18%) upgrades"',FALSE,TRUE,''),
('Harrison Trace - Homes for Rent','6 - Passed','Charlotte-Gastonia-Rock Hill, NC-SC',84,2021,460000,38640000,'2022-03-31','2022-02-24','2022-03-22','T12 & RR saved. No OM yet.
-"Jay, guiding $460k per home.  $2,425 gross monthly rents. Solving to a 4.2% Y1 cap rate which assumes 5% Y1 rent growth which is conservative given continued double digit trade outs in the Carolinas" 
JS: BTR deal in NE CLT, between DT and UNI, area looks ok not great',FALSE,TRUE,''),
('River School Lofts','6 - Passed','Richmond-Petersburg, VA',40,1917,250000,10000000,NULL,'2022-03-10','2022-03-15','all docs saved
-"$10M"',FALSE,TRUE,''),
('Five Oaks','6 - Passed','Atlanta, GA',280,2005,280000,78400000,'2022-03-17','2022-02-23','2022-03-15','T12 & RR saved. No OM yet
-"Price guidance is approaching $80M, or $280ks/unit.  
 
•	2005 Worthing construction, 280-unit property with 9’ ceilings 
•	Recent leases in 1Q22 average $1,794/unit, 27%+ above the current rent roll average
•	All units remain in classic condition with black appliances, laminate counters and original cabinets
•	Fantastic exposure with signage and more than 1,800 feet of frontage along I-285 (177,000 VPD)
•	Superior access to major employment nodes  
•	Less than three miles away, Emory Healthcare is redeveloping Northlake Mall and creating 1,600 new jobs"
JS: Tucker, looks like good location, good vintage, all units classic see notes above - Eaton Vance also has Hawthorne Gates',FALSE,TRUE,''),
('The Fields at Rock Creek','6 - Passed','Washington, DC-MD-VA',314,1990,270700,85000000,'2022-02-24','2022-01-13','2022-03-15','all docs saved
-"We’re targeting ~$85m or $270k per unit which is a 4.3% cap on our proforma. The property is a fantastic value-add play with the ability to push rents $150+ with a comprehensive in-unit rehab & amenity enhancements. The rent growth at the property is very strong with lease trade-outs approaching $250 and the revenue growth is substantial as well. The property is currently 97% occupied with no A/R issues. The Frederick sub market is poised for significant growth over the next couple of years with double digit rent growth projected in 2022." 
JS-looks interesting, still 26% of units to reno, nice location',TRUE,TRUE,''),
('Avalon Grosvenor Tower','6 - Passed','Washington, DC-MD-VA',237,1987,405063,96000000,NULL,'2022-02-14','2022-03-15','all docs saved
-"Great value-add play in Montgomery County, MD along the I-270 corridor and walkable to redline metro"
JS: N Bethesda, looks like decent location, older vintage and large size',TRUE,TRUE,''),
('Villas at West Road','6 - Passed','Houston, TX',240,2006,220833,53000000,'2022-02-24','2022-01-18','2022-03-15','coming soon. no deal room yet
JS-NW HSTN, looks like a nice area, good size, vintage etc.
-"VWR (240 units) Guidance is $53M ($220k/door)" 
-"Barons (508 units) Guidance: $94M ($185k/unit)"
-"Portfolio (748 units) Guidance: $147M"',TRUE,TRUE,''),
('Ledger Union Market','6 - Passed','Washington, DC-MD-VA',134,2020,597014,80000000,'2022-03-03','2022-01-26','2022-03-15','all docs saved
-"Mid-3 cap is $80M"
JS: put on here mainly for interest',TRUE,TRUE,''),
('Rollingwood Apartments','6 - Passed','Washington, DC-MD-VA',283,1963,265017,75000000,'2022-03-09','2022-01-20','2022-03-15','all docs saved
"guiding to $75M, 4% cap on in-place and 4.25% year 1"

JS-good location near Chevy Chase, Will had mentioned looked at these etc. could be interesting',FALSE,TRUE,''),
('Alta Baytown','6 - Passed','Houston, TX',336,2019,175000,58800000,'2022-03-08','2022-02-14','2022-03-15','all docs saved
-"Pricing 175/unit, CFO 3/1"
JS: saw was on board, E of HSTN in Baytown, close to bay / coast',FALSE,TRUE,''),
('Park At Woodland Springs Apartments','6 - Passed','Houston, TX',250,2005,140000,35000000,'2022-03-08','2022-02-08','2022-03-15','all docs saved
-"140,000 a door"
JS: more Spring than Woodlands but could be interesting',FALSE,TRUE,''),
('The Retreat at Cinco Ranch','6 - Passed','Houston, TX',268,2008,245000,65660000,'2022-03-08','2022-02-18','2022-03-15','all docs saved
-"Guidance is $245k/unit for Retreat at Cinco Ranch which is about a 3.5-3.75 cap tax adjusted"',FALSE,TRUE,''),
('Sunrise By The Park','6 - Passed','Houston, TX',180,2015,233333,42000000,'2022-03-10','2022-02-23','2022-03-15','all docs saved
-"$42MM+"',FALSE,TRUE,''),
('10 Perimeter Park','6 - Passed','Atlanta, GA',230,2008,304347,70000000,'2022-03-09','2022-02-10','2022-03-15','RR & T12 saved. No OM yet
-"For 10P, price guidance is low-$70M, north of $300k/u, around a 3% cap in place but trending higher with solid lease trade-outs. Audubon is the owner/operator. 
JS: looks very interesting, good size, location, vintage etc. untouched va
 
•	Developed in 2008 by Alliance – mid-rise with non-conditioned corridors, brick/hardi/stone exteriors, structured and surface parking 
•	230 units with 9 & 10 ft. ceilings, and large floor plans (1,046 SF avg)
•	27%+ lease trade-outs in January, last 20 move-ins average $1,626 | $1.63
•	100% of units in classic condition primed for VA
•	Call for offers not officially locked down but targeting March 9"',FALSE,TRUE,''),
('The Laurel at Altamonte','6 - Passed','Orlando, FL',240,2000,270833,65000000,NULL,'2022-01-12','2022-03-14','all docs saved
JS-good size and vintage and decent location within Orlando',FALSE,TRUE,''),
('Heights West End Apartments','6 - Passed','Houston, TX',283,2015,230035,65100000,'2022-02-28','2022-01-25','2022-03-07','all docs saved
-"$230-235K/unit range"
JS: between Mem Park and DT, newer, prob limited VA',FALSE,TRUE,''),
('Ascend @ 1801','6 - Passed','Charlotte-Gastonia-Rock Hill, NC-SC',408,2000,250000,102000000,'2022-03-01','2022-01-18','2022-03-01','all docs saved
-"Low 250s/unit, 3.25-3.3% trailing yield, 3.5-3.6% in place rent roll/expenses with adjusted taxes"
JS- not too far from Magnolia, just outside 485, good vintage etc but a little large at 100M+',FALSE,TRUE,''),
('Belle Vista Apartment Homes','6 - Passed','Atlanta, GA',312,2001,NULL,NULL,NULL,'2022-02-10','2022-02-28','all docs saved
JS: looks interesting, do not know this area well, looks like an ok area, near a hospital, reno 2017 further va possible',FALSE,TRUE,''),
('Virage Luxury Apartments','6 - Passed','Houston, TX',372,2014,295698,110000000,NULL,'2022-01-04','2022-02-25','coming soon; "$109-111 million"
JS-looks like really good location, near River Oaks, Memorial Park etc., light value-add but likely to large $ wise',FALSE,TRUE,''),
('Verona at Boynton Beach Apartments','6 - Passed','West Palm Beach-Boca Raton, FL',216,2002,347222,75000000,'2022-02-15','2022-01-26','2022-02-23','all docs saved',TRUE,TRUE,''),
('San Paloma Apartments','6 - Passed','Houston, TX',372,2006,NULL,NULL,'2022-02-24','2022-02-17','2022-02-23','all docs saved',FALSE,TRUE,''),
('Arlo Buffalo Heights','6 - Passed','Houston, TX',318,2014,NULL,NULL,'2022-02-23','2022-02-14','2022-02-23','all docs saved
JS: between Mem Park and Downtown, newer may have limited VA',FALSE,TRUE,''),
('High Point Uptown','6 - Passed','Houston, TX',277,2017,250000,69250000,'2022-02-22','2022-02-01','2022-02-23','all docs saved
-"$250k per unit"
JS: also near RivOaks, next to a lot of office / hotels, newer so may be limited VA',FALSE,TRUE,''),
('Sonoma Pointe Apartments','6 - Passed','Orlando, FL',216,2015,314814,68000000,'2022-02-23','2022-01-18','2022-02-23','all docs saved
-"Ask is $68M, $315k per door and a 4% year 1. They are completely full and have seen some incredible recent leasing, with 20% tradeouts, so there''s a great mark-to-market story plus some light upgrade opportunities as well."
JS-newer deal, fast growing area of Orlando, light value-add',FALSE,TRUE,''),
('The Courts of Avalon Apartments','6 - Passed','Baltimore, MD',258,1999,310077,80000000,'2022-03-09','2022-01-24','2022-02-18','T12 & RR saved. no OM yet
-JS-Baltimore, area looks nice, good size, vintage',FALSE,TRUE,''),
('Morehead West','6 - Passed','Charlotte-Gastonia-Rock Hill, NC-SC',212,2015,273584,58000000,'2022-02-08','2022-01-05','2022-02-16','all docs saved
-"Starting pricing guidance is high $50Ms to $60M"
-"Implied low 3% in-place cap rate (T3 revenue | T12 expense)"
-"Initial offers due in early February"
-"Attractive avg $1,245 in-place, mid-rise rents (surface parked), accelerating trade outs (+20% since Sept) and meaningful headroom at a path of growth Charlotte, primary ring address"',TRUE,TRUE,''),
('Carrington Green','6 - Passed','Atlanta, GA',263,2005,220152,57900000,'2022-02-24','2022-01-17','2022-02-16','all docs saved
-Part of the Atlantic Pacific Two Pack Portfolio
-"1) 2004-vintage w/ 20% attached garages and super large units (1,185 SF)
2) In-place rents of $1250, last 60 leases showing $229 bump.
3) No units have been upgraded so pure value-add play
4) No washer/dryers have been installed (all have connections)
5) No valet trash program in place

-In-Place Cap rate (T-1 adjusting for COVID bad debt) is 3.5%
-Pricing is low $220,000/unit or about $191/SF"',FALSE,TRUE,''),
('Villas at South Point','6 - Passed','Atlanta, GA',284,2006,260211,73900000,'2022-02-24','2022-01-17','2022-02-16','all docs saved
-Part of the Atlantic Pacific Two Pack Portfolio
-"1)  2006-vintage “Big House” Design (one of 3 in Atlanta ) with 85% attached garages and large units (1,155 SF)
2) In-place rents of $1,450, last 60 leases showing $390 bump.
3) No units have been upgraded so pure value-add play
4) No washer/dryers have been installed (all have connections)
5) Internet program not fully rolled out so additional income opportunities.

-In-Place Cap rate (T-1 adjusting for COVID bad debt) is 3.65%
-Pricing is low $260,000/unit or $229/SF."',FALSE,TRUE,''),
('Lanes at Union Market','6 - Passed','Washington, DC-MD-VA',110,2022,545454,60000000,NULL,'2022-01-19','2022-02-16','off market
-"3,610 SF of Retail"
-"Owner is Ranger Properties out of NY (http://www.rangerproperties.com/)"
-"The building was originally designed with coliving in mind
-	It is currently a construction site 
-	See below unit mix and attached designs 
-	Current designs have no living rooms in the units (replaced with a bedroom)
-	It can be operated as conventional, but most likely each unit would lose a bedroom for a living room (2br/1ba ? 1br/1ba, 3br/2ba ? 2br/2ba)"
-"Common stats from i5 Union Market, next door:
-	Fastest lease up in the portfolio
-	Leased 130 beds in 2 months
-	Went from 60% occupied to close to 100% occupancy
-	Units Lanes have a better layout than units at i5 (based on comments from coliving operator)"
JS-off market from CBRE, under construction, presale/no topa',FALSE,TRUE,''),
('Providence Lakes Apartments','6 - Passed','Tampa-St. Petersburg-Clearwater, FL',260,1996,307692,80000000,'2022-02-23','2022-01-25','2022-02-16','all docs saved
-"Pricing is probably $80MM+ or so"
JS: Brandon, VA, vintage a little older, high p/u',FALSE,TRUE,''),
('Bay Crossing','6 - Passed','Tampa-St. Petersburg-Clearwater, FL',321,1984,280000,89880000,'2022-02-23','2022-02-01','2022-02-16','access requested
-"Thank you for your interest. Bay Crossing represents a tremendous opportunity to acquire a value-add opportunity located in South Tampa one of Tampa Bay’s best rental submarkets. New ownership will be able to increase rents on average $450+/month by building upon the improvements that have been recently completed and implementing a modern interior renovation on all floor plans.  We envision renovations will include the following: updated kitchens with stainless-steel appliances, updated cabinetry and hardware, tile backsplash, upgraded bathrooms, faux-wood vinyl flooring throughout, modern paint schemes, updated lighting, and new hard surface countertops. We anticipate Bay Crossing trading at $280,000++ per unit, which is a 3± cap based on T3 income and T12 expenses adjusted for taxes, building into a 5± cap when all units are brought up to projected rents. Call for offers is February 23rd"
JS: looks like good location, older vintage, VA',FALSE,TRUE,''),
('The Collection Midtown','6 - Passed','Richmond-Petersburg, VA',219,1915,200913,44000000,NULL,'2022-01-24','2022-02-16','all docs saved
"Very strong value-add play here, as rents are well below competing properties. I know you’re familiar with Richmond, which means you’re familiar with the Fan District/Museum District where these properties are located. They stay 100% full, and are easily $250 below market. For example, when we did our kick-off tour, we toured a 2br unit (and these are decent sized units) and it was leasing for $1,250, and was located directly behind the Virginia Museum of Fine arts which is a remarkable location. 

Spy Rock re-developed these utilizing historic tax credits, then sold to current owner Campus Apartments out of Philly. Long story short, the heavy lifting has been done, now all you have to take advantage of are the renovations. Stainless, granite, backsplash, maybe a technology package and some flooring. 

Happy to hop on a call to discuss more, but at $200k/unit for this location, it’s a great basis play, when adaptive re-use deals like this across the street in Scotts Addition look like mid to high 200k/unit mark." 
JS-looked interesting but prob not for us?',FALSE,TRUE,''),
('Copper Mill Apartments','6 - Passed','Richmond-Petersburg, VA',192,1987,239583,46000000,'2022-02-22','2022-01-18','2022-02-16','access requested
JS-put on here for ref to CS',FALSE,TRUE,''),
('Hunter''s Chase Apartments','6 - Passed','Richmond-Petersburg, VA',320,1986,234375,75000000,'2022-03-01','2022-02-10','2022-02-16','all docs saved
-"Around $75m"
JS: older vintage, location looks ok / far out',FALSE,TRUE,''),
('Glenmoor Oaks','6 - Passed','Richmond-Petersburg, VA',248,2020,254032,63000000,'2022-02-22','2022-02-01','2022-02-16','all docs saved
-"Guidance here is $63M, but important to know this is a ground-lease execution"
JS: ground lease dq it',FALSE,TRUE,''),
('Legends Cary Towne','6 - Passed','Raleigh-Durham-Chapel Hill, NC',354,2001,282485,100000000,'2022-02-17','2022-01-17','2022-02-16','all docs saved
JS-good location in between Raleigh and Cary, good vintage etc but large $ wise',FALSE,TRUE,''),
('Millbrook Apartment Homes','6 - Passed','Raleigh-Durham-Chapel Hill, NC',117,1986,205000,23985000,NULL,'2022-02-15','2022-02-16','all docs saved
-"Guidance is $205K/door (~$45M). Mid 3 on in-place rents"
JS: portfolio with Lake Lynn, looks like good location but older vintage',FALSE,TRUE,''),
('Lynn Lake Apartment Homes','6 - Passed','Raleigh-Durham-Chapel Hill, NC',101,1986,205000,20705000,NULL,'2022-02-15','2022-02-16','all docs saved
-"Guidance is $205K/door (~$45M). Mid 3 on in-place rents"
JS: portfolio with Millbrook, looks like good location but older vintage',FALSE,TRUE,''),
('VERT at Six Forks','6 - Passed','Raleigh-Durham-Chapel Hill, NC',174,1986,205000,35670000,'2022-03-01','2022-01-26','2022-02-16','all docs saved
-"•	Guidance is $205k per unit, low to mid 3% cap on in-place NOI; comfortably below garden replacement cost of $240-$250k per unit and well-below new construction trades of $300k+ per unit. 
 
•	Unique floorplans with townhomes, lofts and flats and a near $400/mo. rental gap with direct value-add comps that have higher renovation scope.  
 
•	Opportunity to update unit interiors on all units but most notably to add granite countertops and vinyl-plank flooring in 132 of 174 units, and paint cabinets in all units.
 
•	No notable deferred maintenance needs – full exterior paint job in 2019, roofs are 2009-2011, no poly piping or aluminum wiring.
 
•	No new supply can access this part of old Raleigh – only 1,000 units have been added in the last 10 years in North Raleigh so the asset has essentially no inhibitors to strong rent growth year-over-year.  
 
•	Average incomes in a 1-mile radius are $105k per year and property is 1-mile from Whole Foods Market and Harris Teeter. 
 
•	Interstates 440, 540 & 40 are also close-by affording residents an easy commute to Research Triangle Park, Durham/Duke Medical, UNC-Chapel Hill, Downtown Raleigh, and North Hills."
JS: great location but talked about how this will be too comp due to size and location',FALSE,TRUE,''),
('Banyan Grove','6 - Passed','Norfolk-Virginia Beach-Newport News, VA-NC',288,2003,284722,82000000,'2022-03-01','2022-02-04','2022-02-16','all docs saved
-"$82mm"
JS: ok nearby retail, VirgBeach, good vintage, are we int in this mkt?',FALSE,TRUE,''),
('Arrabella','6 - Passed','Houston, TX',232,2014,323275,75000000,NULL,'2022-02-01','2022-02-16','coming soon
-"Around $75M"
JS: Katy, newer, TH style, could be interesting',FALSE,TRUE,''),
('The Lofts at Woodside Mill','6 - Passed','Greenville-Spartanburg-Anderson, SC',307,2021,358306,110000000,NULL,'2022-02-14','2022-02-16','access requested
-"Pricing is $110M, which includes value for the 20 year tax abatement. The product is really cool, very unique, and they had a fast 10 month lease up with virtually no concessions along the way. With the abatement you’re looking at a 4.5% cap going in, so a really strong core+ profile on this one"
JS: new deal in gville, prob not for us, looked nice / interesting but prob not for us',FALSE,TRUE,''),
('Arbor Village Apartment Homes','6 - Passed','Charlotte-Gastonia-Rock Hill, NC-SC',220,1984,230000,50600000,'2022-02-23','2022-01-19','2022-02-16','all docs saved
"Low $230ks/door range"
JS-older, but nice location in S CLT near myers park etc.',FALSE,TRUE,''),
('The Spoke at McCullough Station','6 - Passed','Charlotte-Gastonia-Rock Hill, NC-SC',124,1990,197580,24500000,NULL,'2022-02-14','2022-02-16','coming soon
-"•	Ownership acquired the property in March 2021 and successfully completed the conversion from an extended-stay hotel into an impressive, fully-leased, 124-unit, market-rate multifamily community
•	In addition to converting the operations, ownership rebranded the signage and exteriors while also introducing a brand-new set of amenities to the property, including a clubhouse w/ presentation kitchen, leasing office, modern fitness center, WiFi lounge, indoor bike storage, outdoor grilling stations, mail kiosk, package room and centralized laundry facility
•	Additional amenity enhancements could include adding a game room in the clubhouse, installing a pet wash area and creating a dog park 
•	The property leased-up incredibly quickly at a pace of 25 units per month which provides mark-to-market upside and the ability to implement a value-add program in 100% of the units
•	Based on the asset’s current positioning compared to Class-A comps and newer construction in the University City submarket (specifically Verde at McCullough Station), we believe significant value-add upside remains
•	Also conveyed with the offering is a ±3.78-acre land parcel adjacent to the property with optionality to develop 35 additional units

Initial pricing guidance is upper $190s/u which is approximately $24-$25M"
JS: smaller deal in university submarket, prob not for us will get a lot of int from smaller groups due to size',FALSE,TRUE,''),
('The Avant at Steele Creek','6 - Passed','Charlotte-Gastonia-Rock Hill, NC-SC',456,2007,278508,127000000,NULL,'2022-02-01','2022-02-16','all docs saved
-"275-280/unit, upper 120Ms. 3.4-3.5 in place, big tradeouts"
JS: S Clt neat Ft Mill, looks nice but too large',FALSE,TRUE,''),
('Echelon at Odenton Apartments','6 - Passed','Baltimore, MD',244,2016,420081,102500000,NULL,'2022-02-14','2022-02-16','all docs saved
-"$100 - $105 MM"
probably not for us, too large',FALSE,TRUE,''),
('Terraces At Suwanee Gateway','6 - Passed','Atlanta, GA',335,2013,322388,108000000,NULL,'2022-02-08','2022-02-16','coming soon. no docs yet
-"Terraces should trade in the +/- $108M range (3.35 – 3.5% cap rate) with average unit size of 1030 (with attached garages approximately 1130).  A few highlights: 
* New Leases are 25% higher ($380/unit)
* On average, the property’s rent are $500 - $700 below market (for similar and newer deals in the submarket)
* Per Axiometrics, rent growth projections for 2022 are 20% and 8%+ for 2023"
JS: looks like ok location within Gwinnett Co., newer build, story seems to be very strong org rent growth (see highlights above)',FALSE,TRUE,''),
('The Row at 26th','6 - Passed','Atlanta, GA',453,2004,331125,150000000,'2022-03-01','2022-02-04','2022-02-16','-"Opportunity to buy scale (453 units) in the heart of Buckhead"
-"Mid-rise, wood-framed product with structured parking built in 2004 by Fairfield"
-"Institutionally owned and maintained since original construction"
JS: looks like nice deal / location but too large
-"Situated on 8 acres at the nexus of Buckhead and Midtown, offering residents a phenomenal “best of both worlds” location"
-"Walking distance to the Northside BeltLine trail, which connects to Bobby Jones Golf Course"
-"Located behind Piedmont Hospital and the Shepard Center, two fast growing, recessionary proof employers"
-"338 (75%) units are primed for value-add renovations"
-"Current ownership has renovated 115 units to a top-of-the-line scope which are achieving $415 above the classic units"
-"New leases average 19.4% higher than the previous in-place lease"
-"Current ownership has spent nearly $3 million on exterior upgrades"
-"Pricing guidance is upper $140Ms to $150M / $320Ks per unit which translates to a 3.2% in-place cap rate adjusted for taxes"',FALSE,TRUE,''),
('The Greens at Centennial Campus','6 - Passed','Raleigh-Durham-Chapel Hill, NC',292,2014,263698,77000000,NULL,'2022-02-01','2022-02-16','all docs saved
-"Guidance here is $77M or mid-$260’s/unit.  Low 3’s in-place with ability to rapidly exceed 4%.  Capital Associates, original developer, is the Seller.
 
•	Beautiful Humphries “E-Urban” design with centralized courtyards within a total of 3 buildings, elevator served, surface parked
•	All original finishes with tremendous opportunity to grow rents through modernizing unit interiors
•	Organic 7% annual NOI growth with 20%+ recent trade-outs.
•	High barrier to entry pocket of Raleigh with over -$500 rent delta to nearby downtown Raleigh and Village District mid-rise product.
•	65 year ground lease (plus extensions) with the State of NC is an attribute to basis and perpetuates the barrier-to-entry story"',FALSE,TRUE,''),
('Marquis at Tanglewood','6 - Passed','Houston, TX',162,1994,209876,34000000,'2022-02-01','2022-01-05','2022-02-16','all docs saved
"Around $34 million"
JS-looks like good location, not too far from River Oaks',FALSE,TRUE,''),
('Provenza at Barker Cypress Apartments','6 - Passed','Houston, TX',318,2014,NULL,NULL,'2022-02-15','2022-01-27','2022-02-15','',FALSE,TRUE,''),
('Waterstone Luxury Apartment Homes','6 - Passed','Houston, TX',276,2012,200000,55200000,'2022-02-15','2022-01-25','2022-02-15','"we think $200k/door and over a 4% on lease trade outs.  CFO is 30 days out"',FALSE,TRUE,''),
('One City Center','6 - Passed','Raleigh-Durham-Chapel Hill, NC',109,2019,527522,57500000,'2022-02-23','2022-01-19','2022-02-15','all docs saved
-"We are guiding to upper $50M range ($530+/unit), and look forward to discussing further"
JS-just put on here for ref',FALSE,TRUE,''),
('Villas at Rockville','6 - Passed','Washington, DC-MD-VA',210,1970,438095,92000000,'2022-02-22','2022-01-06','2022-02-15','no deal room yet
-"They are townhomes"
JS-decent location, TH style ~2k sf, older',FALSE,TRUE,''),
('Summermill At Falls River Apartments','6 - Passed','Raleigh-Durham-Chapel Hill, NC',320,2002,300000,96000000,'2022-02-11','2022-01-10','2022-02-14','all docs saved
JS-not far from Columns, similar size, vintage etc to columns - looks very interesting but large $ wise',TRUE,TRUE,''),
('Vargos on the Lake','6 - Passed','Houston, TX',276,2015,220000,60720000,'2022-02-09','2022-01-25','2022-02-14','all docs saved
-"~220k a unit for this one, great product in a very unique setting"',FALSE,TRUE,''),
('Astor Tanglewood','6 - Passed','Houston, TX',238,2014,218487,52000000,'2022-02-02','2022-01-19','2022-02-14','JS-looks like a nice location, near river oaks, maybe light value-add (pics look fairly good/in line with comps), could be interesting',FALSE,TRUE,''),
('Weston at Copperfield Apartments','6 - Passed','Houston, TX',330,1998,NULL,NULL,'2022-02-08','2022-01-06','2022-02-14','all docs saved
JS-NW HSTN, not too far from villas at west road (also on list), good vintage, size etc.',FALSE,TRUE,''),
('The Glover House','6 - Passed','Washington, DC-MD-VA',226,2020,707964,160000000,NULL,'2022-02-04','2022-02-14','-"$160M+"
-"offered at 4% tax adjusted cap rate"',FALSE,TRUE,''),
('Hazel SouthPark® Apartments','6 - Passed','Charlotte-Gastonia-Rock Hill, NC-SC',203,2021,NULL,NULL,NULL,'2022-01-25','2022-02-14','',FALSE,TRUE,''),
('Glen Rock Landing Apartment Homes','6 - Passed','Washington, DC-MD-VA',304,1965,190789,58000000,'2022-02-01','2022-01-18','2022-02-04','all docs saved
-"Initial guidance is mid-to-high $50 million range and could see $60 million"
-"Below are some additional comments on the opportunity:
--Significantly Below Market Rents: The best comps we feel are Heather Hill and Henson Creek. As the market leaders in this submarket, both are undergoing interior renovation that include the addition of W/D in renovated units only. Example, 2BR/1BA renovated units at Henson Creek are asking as much as $1,890 to $1,990 compared to an average in-place rent of $1,326 for the unrenovated 2BR at Glen Rock.
--2022 Tax Assessment: Taxes have just been reassessed as of January 1, 2022 and are locked in for 3 years. The increased assessment to $40,323,100 will be phased-in over a three year period with a sale of the property note impacting the taxes until 2025. See our OM for more detail.
--Prior Capital Improvements: Significant work completed by both this current and prior ownerships with new capital to focus on in-unit renovations"
JS-past MGM, probably not greatest location, older, just wanted to make sure not for us',FALSE,TRUE,''),
('101 North Ripley Apartments','6 - Passed','Washington, DC-MD-VA',189,1963,NULL,NULL,'2022-02-15','2022-01-07','2022-02-04','',FALSE,TRUE,''),
('The Residences At Congressional Village','6 - Passed','Washington, DC-MD-VA',403,2005,264267,106500000,NULL,'2022-01-25','2022-01-27','T12 & RR saved. no OM yet
-"Pricing is $106.5M ($264K/unit) to $112M ($277k/unit)"
-"4.00% to 4.4% in place – T90 Day Revenue, T12 expenses adjusted for 1st year Ground Lease ($1.05M)"',FALSE,TRUE,''),
('ELEVATION 314','6 - Passed','Washington, DC-MD-VA',52,2004,336538,17500000,NULL,'2022-01-18','2022-01-27','all docs saved
JS-near takoma metro, prob not for us',FALSE,TRUE,''),
('The Centre at Silver Spring Apartments','6 - Passed','Washington, DC-MD-VA',256,1984,261718,67000000,NULL,'2022-01-12','2022-01-27','all docs saved
"will be over 67M"
JS-looks like a decent location (in Mont Co.), nice car dealerships nearby etc., 86% of units left to reno, could be interesting',FALSE,TRUE,''),
('Bleecker Hyde Park Apartments','6 - Passed','Tampa-St. Petersburg-Clearwater, FL',259,2016,405405,105000000,NULL,'2022-01-24','2022-01-27','all docs saved
-"low $400s per unit. 3 cap trailing with substantial upside, both on the interiors and operationally. Location is irreplaceable"
JS-nice location, maybe light value-add, but likely too large $ wise',FALSE,TRUE,''),
('Element Uptown','6 - Passed','Charlotte-Gastonia-Rock Hill, NC-SC',352,2015,425000,149600000,NULL,'2022-01-25','2022-01-27','all docs saved
-"Targeting low to mid $400s per unit. Low to mid 3.00s on going in yield, although clear visibility to a much higher yielding future. That can be accomplished through renovation or CBD bounce-back. Either way, it feels really good at that basis"',FALSE,TRUE,''),
('The Residences at Waterstone','6 - Passed','Baltimore, MD',255,2002,384313,98000000,NULL,'2022-01-26','2022-01-27','coming soon. no docs yet
-"We’re targeting ~$98m or ~$385k per unit which is a 4.2% cap on our proforma.  The current owner has proven out a strong value-add story at the property achieving premiums of $260 per unit per month with a comprehensive in-unit rehab.  The property is also under performing the submarket by $500 on unrenovated units and $250 below on renovated product. The rent growth in the submarket is very strong at 12%+ with lease trade-outs approaching $250 and the revenue growth is substantial as well. The property is currently 97% occupied with no A/R issues. The Pikesville submarket is projected to see substantial double digit rent growth for significant growth thru 2022."',FALSE,TRUE,''),
('Harris Bridge Overlook','6 - Passed','Atlanta, GA',332,2001,228915,76000000,'2022-02-24','2022-01-18','2022-01-27','coming soon. access requested
-"Expected pricing in the $230K’s per unit or higher. That’s just above a 3.72% cap at $76 mm on T1/T12 tax adjusted numbers"
JS-checks some boxes in terms of price, vintage etc but pretty far outside of Atl (NW)',FALSE,TRUE,''),
('Shiloh Valley Overlook','6 - Passed','Atlanta, GA',300,2001,300000,90000000,'2022-02-24','2022-01-18','2022-01-27','coming soon. access requested
-"Expected pricing in around $300K per unit or higher. That’s a little over a 3.37% cap at $90 mm on T1/T12 and numbers just keep getting stronger"
JS-looks like decent location, SE Kennesaw, good size/vintage, a little large at 90M',FALSE,TRUE,''),
('Calvert Woodley Apartments','6 - Passed','Washington, DC-MD-VA',136,1962,426470,58000000,'2021-11-11','2021-10-06','2022-01-27','all docs saved
"Should end up around $58 million"',TRUE,FALSE,''),
('Alder Park','6 - Passed','Atlanta, GA',270,2019,259259,70000000,'2022-02-09','2022-01-07','2022-01-27','-"Guidance for the portfolio is $170M, Marietta Crossing ($100M or $238k/unit) and Alder Park ($70M or $260k/unit)"
-"Both assets recently completed amenity refreshes (tennis court conversions), that turned out exceptional"
-"In addition, both assets have been renovating units over the last three years to bring units to one scope and scale"
-"Alder Park has ~31% of units remaining to be renovated, netting $250-$300 premiums post-renovation"
-"Property level performance at both assets have been robust with recent lease trade outs in the ~20%-30% on new leases and ~10% on renewals"
-"The seller will not transact on one asset without transacting on the other, but they are open to selling as a portfolio or as one-off assets to two different buyers"',FALSE,TRUE,''),
('Azura','6 - Passed','Washington, DC-MD-VA',21,2022,416666,8750000,'2022-02-09','2022-01-19','2022-01-26','',FALSE,TRUE,''),
('Townhomes of Oakleys','6 - Passed','Richmond-Petersburg, VA',160,1974,109375,17500000,NULL,'2022-01-17','2022-01-25','no docs yet',FALSE,TRUE,''),
('The Barons','6 - Passed','Dallas-Fort Worth, TX',508,1999,185039,94000000,NULL,'2022-01-18','2022-01-25','coming soon. no deal room yet',FALSE,TRUE,''),
('Chestnut Oaks','6 - Passed','Washington, DC-MD-VA',149,2007,NULL,NULL,NULL,'2022-01-18','2022-01-25','all docs saved',FALSE,TRUE,''),
('Laurel Springs','6 - Passed','Raleigh-Durham-Chapel Hill, NC',122,1986,NULL,NULL,NULL,'2022-01-06','2022-01-18','all docs saved. Part of the North Raleigh Value-Add Portfolio',FALSE,TRUE,''),
('Laurel Oaks','6 - Passed','Raleigh-Durham-Chapel Hill, NC',164,1989,NULL,NULL,NULL,'2022-01-06','2022-01-18','all docs saved. Part of the North Raleigh Value-Add Portfolio',FALSE,TRUE,''),
('ELEVATION 314','6 - Passed','Washington, DC-MD-VA',52,2004,346153,18000000,'2021-10-21','2021-10-07','2022-01-18','back on market a/o 1/18/22 ??',FALSE,TRUE,'')
ON CONFLICT (name) DO NOTHING;

INSERT INTO deals (name,status,market,units,year_built,price_per_unit,purchase_price,bid_due_date,added,modified,comments,flagged,hot,broker) VALUES
('Mazza GrandMarc Apartments','6 - Passed','Washington, DC-MD-VA',232,2010,301724,70000000,NULL,'2021-12-16','2022-01-12','all docs saved',FALSE,TRUE,''),
('Encore Motif','6 - Passed','Houston, TX',240,2022,230000,55200000,NULL,'2021-12-22','2022-01-10','off market with Dustin
new Greystar development',TRUE,TRUE,''),
('Arcadia Student Living','6 - Passed','Charlotte-Gastonia-Rock Hill, NC-SC',205,2014,NULL,NULL,NULL,'2021-12-16','2022-01-10','all docs saved',FALSE,TRUE,''),
('Chatham Square','6 - Passed','Raleigh-Durham-Chapel Hill, NC',448,2000,310267,139000000,NULL,'2022-01-05','2022-01-10','T12 & Rent roll saved. No OM yet
-"Ask price is $139M or $310K per unit which is a 3.5% cap rate based on in-place rents and stabilized operations, adjusted for post-sale taxes"
-"built in 2000 by Gables (9'' ceilings, nearly 1,200 SF Avg unit size) and was master-leased to Disney up until last year, when the current owner bought the property"
-"Upon acquisition, current ownership terminated the Disney lease, and took the property from 100% vacancy to stabilization in 6 months"
-"With how quickly they leased-up, they are experiencing huge rent increases on recent leases, up to 18% depending on the floor plan"
- "Additionally, have only fully renovated +/- 60 units" 
-"The remaining units will have washer/dryers, white appliances, laminate counters and wood-vinyl flooring in the living areas, so there is a heavy interior renovation opportunity as well"
-"We will call for offers in 30 days"',FALSE,TRUE,''),
('Park at Peachtree Corners Apartment Homes','6 - Passed','Atlanta, GA',460,1985,NULL,NULL,NULL,'2022-01-05','2022-01-10','T12 & Rent roll saved. No OM yet',FALSE,TRUE,''),
('The Villas at River Park West','6 - Passed','Houston, TX',252,2007,186507,47000000,NULL,'2021-11-11','2022-01-10','Off Mkt with Dustin, all docs saved.
"target 47M"',TRUE,FALSE,''),
('The Riverside','6 - Passed','Washington, DC-MD-VA',23,1956,195652,4500000,NULL,'2021-12-09','2022-01-05','all docs saved. Part of the NW3DC portfolio deal.

Broker: No date circled right now. We hit the market in December knowing that some people will get a head start and others wouldn’t be looking at it until this year. That being said, we will let you know if the timing is outside of the normal 45-50 day process.',TRUE,TRUE,''),
('2632 Tunlaw','6 - Passed','Washington, DC-MD-VA',30,1942,183333,5500000,NULL,'2021-12-10','2022-01-05','all docs saved. Part of the NW3DC portfolio deal.

Broker: No date circled right now. We hit the market in December knowing that some people will get a head start and others wouldn’t be looking at it until this year. That being said, we will let you know if the timing is outside of the normal 45-50 day process.',TRUE,TRUE,''),
('2626 Tunlaw','6 - Passed','Washington, DC-MD-VA',35,1943,185714,6500000,NULL,'2021-12-10','2022-01-05','all docs saved. Part of the NW3DC portfolio deal.

Broker: No date circled right now. We hit the market in December knowing that some people will get a head start and others wouldn’t be looking at it until this year. That being said, we will let you know if the timing is outside of the normal 45-50 day process.',TRUE,TRUE,''),
('The Fitzgerald','6 - Passed','Washington, DC-MD-VA',36,1923,244444,8800000,'2021-11-04','2021-09-27','2022-01-04','all docs saved
12.5M total, coming to market soon
part of portfolio with The Carraway',TRUE,TRUE,''),
('The Carraway','6 - Passed','Washington, DC-MD-VA',15,1923,246666,3700000,'2021-11-04','2021-09-27','2022-01-04','all docs saved
12.5M total, coming to market soon
part of portfolio with The Fitzgerald',TRUE,TRUE,''),
('The Park Regent','6 - Passed','Washington, DC-MD-VA',96,1910,210000,20160000,'2021-10-28','2021-10-11','2022-01-04','docs saved. OM saved. Greysteel NW, DC portfolio.',TRUE,FALSE,''),
('Newton Towers','6 - Passed','Washington, DC-MD-VA',56,1964,230000,12880000,'2021-10-28','2021-10-11','2022-01-04','docs saved. OM saved. "Greysteel NW, DC Portfolio."',TRUE,FALSE,''),
('3654 New Hampshire Ave NW','6 - Passed','Washington, DC-MD-VA',28,1928,230000,6440000,'2021-10-28','2021-10-11','2022-01-04','docs saved. OM saved. "Greysteel NW, DC Portfolio."',TRUE,FALSE,''),
('1126 11th Street NW','6 - Passed','Washington, DC-MD-VA',43,1927,210000,9030000,'2021-10-28','2021-10-12','2022-01-04','docs saved. OM saved. "Part of the Greysteel portfolio deal."',TRUE,FALSE,''),
('Reserve at LaVista Walk','6 - Passed','Atlanta, GA',283,2009,300353,85000000,'2021-11-11','2021-10-11','2022-01-04','docs saved. OM saved.
CFO Likely 1st week of Nov',FALSE,TRUE,''),
('1800 16th Street N','6 - Passed','Washington, DC-MD-VA',27,1942,287000,7749000,'2021-11-18','2021-10-18','2022-01-04','docs saved. no OM 10/19. Part of the Swansen Apartment Portfolio deal.  
"We are beginning our guidance at ~$23 million, or $287 thousand per unit, which is a 4.7% cap rate on in-place."',FALSE,TRUE,''),
('1621 N Ode Street','6 - Passed','Washington, DC-MD-VA',23,1965,287000,6601000,'2021-11-18','2021-10-18','2022-01-04','docs saved. No OM 10/19. Part of the Swansen Apartment Portfolio Deal.
"We are beginning our guidance at ~$23 million, or $287 thousand per unit, which is a 4.7% cap rate on in-place."',FALSE,TRUE,''),
('1601 N Rhodes Street & 1600 N Quinn Street','6 - Passed','Washington, DC-MD-VA',30,1942,287000,8610000,'2021-11-18','2021-10-18','2022-01-04','docs saved. No OM 10/19. Part of the Swansen Apartment Portfolio deal.
"We are beginning our guidance at ~$23 million, or $287 thousand per unit, which is a 4.7% cap rate on in-place."',FALSE,TRUE,''),
('Avenue R','6 - Passed','Houston, TX',392,2012,206632,81000000,'2021-11-16','2021-10-11','2022-01-04','docs saved. no OM 10/11.',TRUE,TRUE,''),
('The Reid Apartments','6 - Passed','Atlanta, GA',242,2021,NULL,NULL,NULL,'2021-12-03','2022-01-04','all docs saved',FALSE,TRUE,''),
('3921 Kansas Ave NW','6 - Passed','Washington, DC-MD-VA',24,1952,NULL,NULL,NULL,'2021-10-18','2022-01-04','docs saved. OM saved. Part of the 1023 14th Street SE, portfolio deal.',FALSE,TRUE,''),
('1023 14th Street SE','6 - Passed','Washington, DC-MD-VA',12,1955,NULL,NULL,NULL,'2021-10-18','2022-01-04','docs saved. OM saved. Part of the 3921 Kansas Ave NW, portfolio deal.',FALSE,TRUE,''),
('Henson Creek Apartment Homes','6 - Passed','Washington, DC-MD-VA',450,1966,193333,87000000,NULL,'2021-09-23','2022-01-04','Docs saved. OM saved.',FALSE,TRUE,''),
('Townsend Square Apartments','6 - Passed','Washington, DC-MD-VA',200,1995,NULL,NULL,NULL,'2021-10-18','2022-01-04','docs saved. OM saved.',FALSE,TRUE,''),
('Addison Park Apartments','6 - Passed','Charlotte-Gastonia-Rock Hill, NC-SC',426,1999,NULL,NULL,NULL,'2021-11-02','2022-01-04','all docs saved',FALSE,TRUE,''),
('Vantage at Murfreesboro','6 - Passed','Nashville, TN',288,2020,NULL,NULL,NULL,'2021-12-03','2022-01-04','all docs saved',TRUE,TRUE,''),
('The Pointe At Crabtree','6 - Passed','Raleigh-Durham-Chapel Hill, NC',336,1996,235119,79000000,'2021-10-21','2021-09-22','2021-11-08','all docs saved
"Guidance is $230K-$235K/unit, CFO has not yet been set – likely mid-October"',TRUE,TRUE,''),
('The Rochelle','6 - Passed','Washington, DC-MD-VA',20,1921,350000,7000000,'2021-10-22','2021-10-05','2021-11-03','docs saved. OM saved.',FALSE,TRUE,''),
('The Fields at Cascades','6 - Passed','Washington, DC-MD-VA',320,1995,328125,105000000,'2021-10-28','2021-10-12','2021-11-03','docs saved. OM saved. 
"$105M/$330k per door/3.5% cap on in place"',TRUE,FALSE,''),
('Merrill House Apartments','6 - Passed','Washington, DC-MD-VA',158,1964,348101,55000000,NULL,'2021-10-04','2021-11-03','docs saved. OM saved.
"Guidance is mid $50Ms and there is no planned offer date now"',TRUE,TRUE,''),
('The Dawson Apartments','6 - Passed','Houston, TX',354,2014,185028,65500000,'2021-10-27','2021-09-22','2021-11-03','docs saved - OM saved.
"185/unit is the guidance"',FALSE,TRUE,''),
('Boulders Lakeside Apartments','6 - Passed','Richmond-Petersburg, VA',248,2020,306451,76000000,'2021-10-22','2021-02-25','2021-10-26','Docs saved. OM saved. Part of a portfolio with "the other deal."
CFO around 10/22
"$300k + per door, $76 million"',FALSE,TRUE,''),
('Elm Gardens','6 - Passed','',36,1966,194444,7000000,'2021-10-21','2021-10-04','2021-10-26','all docs saved',FALSE,TRUE,''),
('Gables 820 West','6 - Passed','Atlanta, GA',248,2008,262096,65000000,'2021-10-19','2021-09-23','2021-10-26','docs saved. OM saved.',TRUE,TRUE,''),
('Bridges At Southpoint Apartment Homes','6 - Passed','Raleigh-Durham-Chapel Hill, NC',192,1987,213541,41000000,'2021-10-07','2021-09-23','2021-10-26','Bridges at Southpoint & Woods Edge Deal. Docs saved. OM saved .
"98 million
+- 215k for each"',TRUE,TRUE,''),
('Woods Edge Apartments','6 - Passed','Raleigh-Durham-Chapel Hill, NC',264,1985,215909,57000000,'2021-10-07','2021-09-23','2021-10-26','Bridges at Southpoint & Woods Edge Deal. Docs saved.  OM saved.
"98 million
+- 215k for each"',TRUE,TRUE,''),
('Magnolia Vinings','6 - Passed','Atlanta, GA',400,1996,275000,110000000,'2021-11-02','2021-10-05','2021-10-26','docs saved. OM saved.',FALSE,TRUE,''),
('401 Oberlin','6 - Passed','Raleigh-Durham-Chapel Hill, NC',243,2014,316872,77000000,'2021-10-18','2021-07-28','2021-10-26','all docs saved. OM saved.

New, maybe coming to market soon, maybe off mkt opportunity from Howard

Resotre to core, 2014 with underwhelming finishes, great location

77 mil ask includes decent amount of retail; backing that out its high 200k''s / dr (per Howard)',FALSE,TRUE,''),
('7 Riverway','6 - Passed','Houston, TX',175,2007,485714,85000000,'2021-10-13','2021-10-11','2021-10-18','docs saved. OM saved.',FALSE,TRUE,''),
('SkyHouse Midtown','6 - Passed','Atlanta, GA',320,2013,NULL,NULL,'2021-10-19','2021-09-23','2021-10-18','Docs saved. OM saved.',FALSE,TRUE,''),
('425 East 80th Street','6 - Passed','New York, NY-NJ',40,NULL,325000,13000000,NULL,'2021-08-04','2021-10-18','broker PF 556k NOI ~4.25 cap',FALSE,TRUE,''),
('Park156 Apartments','6 - Passed','Atlanta, GA',222,2001,NULL,NULL,NULL,'2021-09-07','2021-10-18','all docs saved',FALSE,TRUE,''),
('Kenyon House Apartments','6 - Passed','Washington, DC-MD-VA',49,1925,275000,13475000,'2021-09-14','2021-10-05','2021-10-18','docs saved. OM saved. Building renovated 1925.
"Offers so far are between $265 and $275/ unit;
Kenyon lower, New Quin a little higher."',TRUE,TRUE,''),
('New Quin Apartments','6 - Passed','Washington, DC-MD-VA',107,1928,275000,29425000,'2021-09-14','2021-10-05','2021-10-18','docs saved. OM saved. Building Renovated 2012.
"Offers so far are between $265 and $275/ unit;
Kenyon lower, New Quin a little higher."',TRUE,TRUE,''),
('Amber Commons','6 - Passed','Washington, DC-MD-VA',198,1968,270202,53500000,'2021-10-12','2021-10-05','2021-10-18','all docs saved',TRUE,FALSE,''),
('The Columns at Sweetwater Creek','6 - Passed','Atlanta, GA',270,2000,NULL,NULL,'2021-10-12','2021-09-23','2021-10-18','Docs saved. OM saved.',FALSE,TRUE,''),
('Park West End Apartments','6 - Passed','Richmond-Petersburg, VA',312,1985,NULL,NULL,'2021-10-14','2021-09-23','2021-10-18','Docs saved. OM saved.',FALSE,TRUE,''),
('Columbia Crossing Apartments','6 - Passed','Washington, DC-MD-VA',247,1991,421052,104000000,'2021-10-12','2021-09-23','2021-10-18','Docs saved. OM saved.',FALSE,TRUE,''),
('Crosswynde Apartments','6 - Passed','Tampa-St. Petersburg-Clearwater, FL',318,2001,226415,72000000,'2021-10-14','2021-09-22','2021-10-15','Docs saved. OM saved.',FALSE,TRUE,''),
('Berkeley Place Apartments','6 - Passed','Charlotte-Gastonia-Rock Hill, NC-SC',368,2001,264945,97500000,'2021-10-13','2021-09-23','2021-10-15','docs saved. OM saved.
"•	Pricing guidance is in the $260s/u (~mid/high $90Ms)
•	Initial offers likely due mid-October"',FALSE,TRUE,''),
('The Artistry at LoSo','6 - Passed','Charlotte-Gastonia-Rock Hill, NC-SC',350,2021,NULL,NULL,NULL,'2021-10-05','2021-10-15','docs saved. OM saved.',FALSE,TRUE,''),
('410-412 W 46th Street','6 - Passed','New York, NY-NJ',30,NULL,390000,11700000,NULL,'2021-08-04','2021-10-15','entirely vacant, gut renovate and lease up business plan. Docs saved. OM saved.',FALSE,TRUE,''),
('Common Monroe','6 - Passed','Washington, DC-MD-VA',8,2019,NULL,NULL,NULL,'2021-10-05','2021-10-15','docs saved. OM saved. (8-units, 46 Bedrooms, 37 Baths)',FALSE,TRUE,''),
('1234 Locust Street','6 - Passed','Philadelphia, PA-NJ',24,1932,NULL,NULL,NULL,'2021-10-06','2021-10-15','docs saved. OM saved. building renovated in 2018.',FALSE,TRUE,''),
('Deca Camperdown','6 - Passed','Greenville-Spartanburg-Anderson, SC',217,2020,599078,130000000,NULL,'2021-09-22','2021-10-15','all docs saved
"$130M, we should be releasing the Om and material tomorrow, haven’t set an official CFO date yet, but expect it’ll be about 4 weeks from now."',FALSE,TRUE,''),
('Holmead','6 - Passed','Washington, DC-MD-VA',101,NULL,198019,20000000,NULL,'2021-10-07','2021-10-15','emailed Cameron for link to materials',FALSE,TRUE,''),
('Tranvia','6 - Passed','Washington, DC-MD-VA',32,2021,NULL,NULL,NULL,'2021-10-11','2021-10-15','docs saved. OM saved.',FALSE,TRUE,''),
('Delaney Apartment Homes','6 - Passed','Charlotte-Gastonia-Rock Hill, NC-SC',240,2010,285000,68400000,'2021-10-21','2021-10-04','2021-10-15','Docs saved. OM saved.
"Pricing is mid $280s per unit which is ~$240 psf. Note the property is 79% two and three-bedrooms so you get a little headline skew on price per unit."',FALSE,TRUE,''),
('Creekside Corners Apartment Homes','6 - Passed','Atlanta, GA',444,2001,NULL,NULL,'2021-10-13','2021-10-04','2021-10-15','docs saved. OM saved.',FALSE,TRUE,''),
('District at Memorial','6 - Passed','Houston, TX',326,2016,NULL,NULL,NULL,'2021-10-11','2021-10-15','docs saved. no OM 10/11.',FALSE,TRUE,''),
('Decatur Highlands','6 - Passed','Atlanta, GA',368,1998,315217,116000000,'2021-10-14','2021-09-23','2021-10-15','No docs available. No OM 10/13. CA signed. Atlanta Pipeline saved.',FALSE,TRUE,''),
('Villas at Hermann Park','6 - Passed','Houston, TX',320,2000,200000,64000000,'2021-10-06','2021-09-21','2021-10-11','All docs saved.
"We are thinking around $200K per door"',FALSE,TRUE,''),
('Heights at Park Lane','6 - Passed','Dallas-Fort Worth, TX',325,2008,350769,114000000,'2021-10-07','2021-09-23','2021-10-11','Docs saved. OM saved.
"pricing guidance here is pushing mid-$300k/door ($108mm - $114mm)"',FALSE,TRUE,''),
('Hudson Northridge Apartments','6 - Passed','Atlanta, GA',220,2017,NULL,NULL,'2021-10-07','2021-09-23','2021-10-11','All docs saved. OM saved.',FALSE,TRUE,''),
('Hudson Willow Trail Apartments','6 - Passed','Atlanta, GA',224,1985,NULL,NULL,'2021-10-07','2021-09-23','2021-10-11','Docs saved. OM saved.',FALSE,TRUE,''),
('1000 West','6 - Passed','Charleston-North Charleston, SC',240,2009,237500,57000000,'2021-10-05','2021-09-21','2021-10-11','All dos saved. OM saved.
"High 230s/unit"',FALSE,TRUE,''),
('Waterside at Reston Apartments','6 - Passed','Washington, DC-MD-VA',276,1985,NULL,NULL,'2021-10-04','2021-09-23','2021-10-11','Docs saved. OM saved.',FALSE,TRUE,''),
('Broadstone Post Oak','6 - Passed','Houston, TX',272,2014,NULL,NULL,'2021-10-07','2021-09-23','2021-10-11','Docs saved. OM saved.',FALSE,TRUE,''),
('Park at Kingsview Village','6 - Passed','Washington, DC-MD-VA',326,2001,309815,101000000,'2021-09-30','2021-08-31','2021-10-11','Docs saved. OM saved.
"$98M to $103M"',FALSE,TRUE,''),
('Glenwood Vista Apartment Homes','6 - Passed','Atlanta, GA',264,2003,178030,47000000,'2021-10-04','2021-08-31','2021-10-11','saved docs, OM saved.
"Be thinking $175K-$185K/door"',FALSE,TRUE,''),
('Cheval','6 - Passed','Houston, TX',387,2005,175710,68000000,'2021-10-07','2021-09-02','2021-10-11','all docs saved',TRUE,TRUE,''),
('Hudson Montford Apartments','6 - Passed','Charlotte-Gastonia-Rock Hill, NC-SC',204,1999,289215,59000000,'2021-10-06','2021-09-07','2021-10-11','financials saved, OM saved.

"high $280’s per unit (~$59M) "

"we are guiding in the $280’s per unit here which represents ~4% cap on year one numbers. All units have been renovated and they are seeing ~7% lease trade outs on both renewals and new leases. See below for the high level deal summary. 
 
In terms of timing, the seller would like to close by the end of the year and first round bids are due on September 29th.
 
Hudson Montford // Charlotte, NC // 204 Units // Built 1999
•	Link to Confidentiality Agreement for Financials Click Here
•	Pricing Guidance: 
o	$280K’s/unit representing ~4% on year 1 and High 3% on in-place
•	Asset Highlights:
o	Proven Operating Momentum: New leases showing 7% lease trade-outs on both renewals and new leases
o	$6.3M Capital Infusion: Completed Renovated Interiors rivaling new-built product
o	Differentiated Product: Massive 1,065 SF floorplans far outpace comps
o	Large Rent Runway: Trailing neighboring submarkets South End and SouthPark by $425 and $600 respectively
•	Submarket Highlights:
o	Centrally Located: Barbelled by Uptown and SouthPark with access to 196,000 jobs within a 15 minute drive
o	Irreplaceable Micro Location: Unparalleled convenience to high quality dining, entertainment and retail options in Montford Park
o	Blue Chip Demographics: 
?	60% Hold Bachelor’s Degree
?	72% White Collar Workforce
?	$138K Avg HHI
?	$515K Median home value - Home values have increased an average of 11% Y-o-Y since 2012"',FALSE,TRUE,''),
('7001 Arlington at Bethesda Apartments','6 - Passed','Washington, DC-MD-VA',140,2015,514285,72000000,'2021-09-30','2021-08-17','2021-10-11','all docs saved
"Low $70m range which is ~3.75% in place"',TRUE,TRUE,''),
('Alvista Durham Apartments','6 - Passed','Raleigh-Durham-Chapel Hill, NC',345,1987,198550,68500000,'2021-09-29','2021-09-30','2021-10-11','all docs saved',TRUE,TRUE,''),
('Berkshire Fort Mill','6 - Passed','Charlotte-Gastonia-Rock Hill, NC-SC',248,2011,197580,49000000,'2021-09-28','2021-08-31','2021-10-11','all docs saved
"•	Pricing guidance is high-$40M to $50M (~$200k/u)
•	Initial offers likely due end of September/beginning of October"',TRUE,TRUE,''),
('Brentmoor Apartments','6 - Passed','Raleigh-Durham-Chapel Hill, NC',228,2003,219298,50000000,'2021-09-29','2021-09-07','2021-10-11','saved Financials, OM saved.
part of portfolio with Hudson High House
"•	Brentmoor ~$215-220K/door "',TRUE,TRUE,''),
('Hudson High House Apartments','6 - Passed','Raleigh-Durham-Chapel Hill, NC',302,1997,264900,80000000,'2021-09-29','2021-09-07','2021-10-11','saved financials, OM saved.
part of portfolio with Brentmoor
"•	Hudson High House ~$260-265K/door "',TRUE,TRUE,''),
('The Abbey Apartments','6 - Passed','Charlotte-Gastonia-Rock Hill, NC-SC',260,2017,346153,90000000,'2021-10-01','2021-09-23','2021-10-11','Docs saved. OM saved.',FALSE,TRUE,''),
('Braxton at Brier Creek Apartments','6 - Passed','Raleigh-Durham-Chapel Hill, NC',270,2004,264814,71500000,'2021-09-22','2021-08-31','2021-10-04','financials saved, no OM 8/31
"Braxton Brier Creek ~$260K/door"',FALSE,TRUE,''),
('The Hudson Apartments','6 - Passed','Richmond-Petersburg, VA',225,2009,157333,35400000,'2021-09-29','2021-09-23','2021-10-01','all docs saved
"We’re targeting $35.4m or ~$158k per unit which is a 4.35% cap with substantial value-add upside thru a strategic in-unit renovation.  The property has proven out $200+ premiums thru the renovation of ~25 units at the property.  Additionally, the newer Class A product in the submarket has put a really good ceiling on the submarket creating a $600+ premium.  Also, there is some additional amenity creation that you can do here to enhance the common areas.    The rent growth in Richmond is very strong and with the ability to push rents $200+ on a renovation makes the returns here hum.  We''re looking to take initial offers on September 29th."',FALSE,TRUE,''),
('1160 Hammond Apartments','6 - Passed','Atlanta, GA',345,2014,301449,104000000,NULL,'2021-09-07','2021-09-28','signed CA 9/7, waiting on access

"Guidance is ~$300k/unit (+/-$104M)."',FALSE,TRUE,''),
('Camden Forest & Wilshire Landing','6 - Passed','Wilmington, NC',200,2013,200000,40000000,NULL,'2021-08-31','2021-09-28','all docs saved
"targeting north of $40.0 million which is ~$170 per sq.ft. That should get to a 20.0%+ LIRR"',FALSE,TRUE,''),
('Braxton Cary Weston Apartments','6 - Passed','Raleigh-Durham-Chapel Hill, NC',288,1995,234375,67500000,NULL,'2021-08-31','2021-09-28','financials saved, no OM 8/31
"Braxton Cary Weston ~$230-235K/door (debt assumption – see war room for loan info) "',FALSE,TRUE,''),
('Station at Mason Creek','6 - Passed','Houston, TX',291,2001,164948,48000000,'2021-09-21','2021-08-06','2021-09-24','coming to market soon
managed by ZRS, Value-Add – ZRS has done a couple of renovations but thinks there is a lot more potential
"pricing is $48mm"',TRUE,TRUE,''),
('Cielo Apartments','6 - Passed','Charlotte-Gastonia-Rock Hill, NC-SC',205,2010,314634,64500000,'2021-09-21','2021-08-31','2021-09-24','all docs saved
part of a portfolio with SouthPark Morrison

overall pricing at "310-315k per unit" from John Heimberger. Set expected price to 315k / unit for both properties',TRUE,TRUE,''),
('SouthPark Morrison','6 - Passed','Charlotte-Gastonia-Rock Hill, NC-SC',214,2007,314953,67400000,'2021-09-21','2021-08-31','2021-09-24','all docs saved
part of a portfolio with Cielo

overall pricing at "310-315k per unit" from John Heimberger. Set expected price to 315k / unit for both properties',TRUE,TRUE,''),
('Preserve at Dunwoody','6 - Passed','Atlanta, GA',302,1984,NULL,NULL,NULL,'2018-11-28','2021-09-21','',TRUE,TRUE,''),
('Concord Apartments','6 - Passed','Raleigh-Durham-Chapel Hill, NC',228,1991,212719,48500000,'2021-09-14','2021-08-31','2021-09-15','all docs saved
"•	Starting Concord guidance: $48.5M | $212K PU 
•	Cap Rates: 
•	3.77% in-place cap rate (T1 GPR/T12/FY1 RET)
•	3.48% tax adjusted (reset in FY3; pull forward assuming 95% of Price and 5% mil rollback; 1.5%/yr increase in mil rate otherwise) 
•	3.94% in-place (3.63% tax adj) based on T90 (see below); essentially 100% occupied and good headroom
•	Delivered free & clear
•	Offers due 9/14
 
•	Compelling VA opportunity with premium rental growth in top tier N Raleigh submarket: 
o	1991 vintage, 3-story garden, 32|45|24% 1|2|3 BRs, attractive avg $1,112 ($1.20/SF) starting rents
o	99.1% occupied 
o	Neighborhood feel nearby 5.6K acre Umstead State Park, 1.1 miles to nearest Harris Teeter, 1.3 miles to UNC Rex Hospital: https://goo.gl/maps/Xgx3ZSNeUEhA4NZo8
o	Average home values at 1.4x MSA and sales peaking +$1M within 1-mile
o	RR GPR equivalent to 12% rent-to-income and +$1,150 ownership premium 
o	Recent-2 leases +8.0% vs RR
o	Compelling front and back-door trade-outs per table below (T90 represents 38% of units, spread across unit mix equivalent to +2.5% vs RR GPR):

 

o	Proven, light VA to date with and room to enhance and fully renovate (23% of units are dated renos or classics)
o	Most recent neighborhood/comp sale = Cortland Olde Raleigh next door (4 years newer, +$350 of headroom on a like unit mix; per Axio)"',FALSE,TRUE,''),
('Camden Largo Town Center Apartments','6 - Passed','Washington, DC-MD-VA',245,2002,265306,65000000,'2021-09-14','2021-08-09','2021-09-15','all docs saved
"We’re offering guidance of $65mm ($265k/unit), which works out to 5.25% T3/T12 cap rate.  Camden is the original owner/developer and all the units are 2002 vintage finishes."',FALSE,TRUE,''),
('Two Blocks','6 - Passed','Atlanta, GA',400,2008,275000,110000000,'2021-09-17','2021-08-31','2021-09-15','all docs saved
"•	Pricing is $110M ($275k per unit), which is a 4.24% cap based on their recent leases.  
•	Trade-outs of 19.5% on new leases, 6.75% on renewals
•	95% occupied and 99% leased
•	Ownership has partially renovated 172 units (43% of the property).  There is an opportunity to upgrade the 228 classic units as well as enhance the upgrades on the partially renovated units.
•	No supply under construction in Central Perimeter, which was halted by a moratorium on Wood Framed construction.  The only development in the pipeline is High Street, which will be concrete and steel construction ($400/sf).  "',FALSE,TRUE,''),
('Artisan at Lake Wyndemere','6 - Passed','Houston, TX',320,1999,203125,65000000,'2021-08-24','2021-07-19','2021-09-10','all docs saved',TRUE,TRUE,''),
('Northchase Village','6 - Passed','Houston, TX',232,2007,155172,36000000,NULL,'2021-07-29','2021-09-02','all docs saved
"$36M range. "',FALSE,TRUE,''),
('Arlo Memorial','6 - Passed','Houston, TX',414,2016,214975,89000000,NULL,'2021-08-31','2021-09-02','all docs saved',FALSE,TRUE,''),
('Ravinia Apartments','6 - Passed','Houston, TX',232,2000,125000,29000000,NULL,'2021-08-31','2021-09-02','all docs saved',FALSE,TRUE,''),
('49 North & University Village','6 - Passed','Charlotte-Gastonia-Rock Hill, NC-SC',298,2007,293288,87400000,NULL,'2021-08-31','2021-09-02','all docs saved
"200psf - For reference, Highlands at Alexander Pointe is pushing $290k per unit, which is north of $250 per sq.ft. before accounting for value-add basis increase. That is a 2002-vintage asset which is 71%+ 2br and 3br units, so a good comp the post-conversion story here."',FALSE,TRUE,''),
('Palmetto Place','6 - Passed','Charlotte-Gastonia-Rock Hill, NC-SC',184,1996,163043,30000000,'2021-08-26','2021-08-04','2021-08-30','all docs saved
"Palmetto Place
 
•	Pricing: $160s per unit, CFO is still TBD but likely to be 8/26
•	It’s a mid-3 cap on the in-place numbers. While we believe the risk profile of the submarket and the deal, given where rents are relative to the comps, are worthy of such a cap rate, I don’t think it’ll be that low soon after you buy it – 21% trade outs happening now
•	Deal link: https://my.rcm1.com/handler/modern.aspx?pv=PxoC4eijlKBfzK8SMYoQDfWl_OJu0vvDu4FCsb7U9QQ#_top
•	Market overview:  
o	Fastest growing city in the nation with 11% annual pop growth 2011-2021, driven by the #1 schools in the state of SC, 15 min proximity to Charlotte’s meteoric growth, major local corporate relocation wins such as Lash Group and LPL Financial
o	Zero future supply on the horizon: 232 units in lease up, nothing under construction or in planning. 
?	Driven by $12k per unit impact fees for multifamily across York County instituted in 2018 and still prevailing today
o	Commercial development continues with “Tepper Town” the NFL’s Carolina Panthers’ corporate campus and practice complex / fan experience underway just 4 miles south of the property
•	Property overview:         
o	$350-$650 rent spread with granite comps in 1 mile radius over the current owner renovation 
o	50% of units have laminate reno – opportunity to take 100% of units to granite and close $250+ of the rent disparity
o	Other income:  washer dryer install, smart home, fenced back yards, valet trash all available
o	Not currently on daily pricing software
•	Capital
o	Newer roofs, vinyl and brick siding, new seal and stripe, full replacement property wide of water-heaters"',TRUE,TRUE,''),
('The Views at Jacks Creek','6 - Passed','Atlanta, GA',256,1997,NULL,NULL,NULL,'2021-08-05','2021-08-26','Ph 1 (40 units) built in 87, balance built in 97',FALSE,TRUE,''),
('Florida SFR Portfolio','6 - Passed','Orlando, FL',170,20102020,352941,60000000,'2021-08-25','2021-08-05','2021-08-23','all docs saved
Avg year built 2018 (2010-2020)
overhalfofthehomesarelocatedintheTampaandMiamimetros.Meanwhile,thebalanceofthePortfolioislocatedintheJacksonville,Orlando,andSouthwestFloridametros',FALSE,TRUE,''),
('South Florida SFR Portfolio','6 - Passed','Miami, FL',50,NULL,350000,17500000,'2021-08-25','2021-07-19','2021-08-23','all docs saved',FALSE,TRUE,'')
ON CONFLICT (name) DO NOTHING;

INSERT INTO deals (name,status,market,units,year_built,price_per_unit,purchase_price,bid_due_date,added,modified,comments,flagged,hot,broker) VALUES
('Lakeview & Lakeview Estate','6 - Passed','Houston, TX',566,19921999,141342,80000000,NULL,'2021-08-05','2021-08-23','all docs saved
Portfolio, next door to each other (1992 / 1999)
"The target is $80 million to the loan which is a solid 5% in place tax adjusted and a 5.5%+ cap year 1.  Both phases are 99% occupied and they are still offering concessions.  Good value-add story as well."',FALSE,TRUE,''),
('ARIUM Wildwood','6 - Passed','Houston, TX',288,2005,154861,44600000,'2021-08-26','2021-07-29','2021-08-23','all docs saved
"Mid 150s a unit for this one"',FALSE,TRUE,''),
('Mark at West Midtown','6 - Passed','Atlanta, GA',244,2016,286885,70000000,'2021-08-12','2021-07-19','2021-08-23','all docs saved
"Best guess is +/- $70 million.  There is a really good basis story here relative to the submarket.  Recent trades close by are $400k+ per unit. "',FALSE,TRUE,''),
('ARIUM Mooresville','6 - Passed','',268,2000,233208,62500000,'2021-08-17','2021-07-27','2021-08-23','all docs saved
"Guidance on the Mooresville deal is low $60Ms.

We are accepting individual offers and we see a viable path to having the properties split up. Not everyone is greenlighted for each of the markets and some of the feedback we have received is that one-off properties in four different locations doesn’t provide enough scale to justify entering a new market, so we would encourage you to submit individually on Mooresville."',FALSE,TRUE,''),
('The Reserve at Fall Creek Apartments','6 - Passed','Houston, TX',264,2009,172348,45500000,'2021-08-18','2021-08-18','2021-08-23','all docs saved
"45-46M"',FALSE,TRUE,''),
('3800 Main Apartments','6 - Passed','Houston, TX',319,2015,219435,70000000,NULL,'2021-08-18','2021-08-23','all docs saved
"220 per unit"',FALSE,TRUE,''),
('Timbercrest','6 - Passed','Charlotte-Gastonia-Rock Hill, NC-SC',282,2000,197517,55700000,'2021-08-18','2021-07-19','2021-08-23','all docs saved
SE CLT, off 74, next o McAlpine Park, area / retail does not look particularly nice
units 100% unreno, near future public transit stop
"We are guiding to high $190s per unit. We have not yet set an offer date, but it will likely be mid-August."',FALSE,TRUE,''),
('The Aster Buckhead Apartments','6 - Passed','Atlanta, GA',224,1999,250000,56000000,'2021-08-19','2021-07-23','2021-08-23','all docs saved
"Jay, price guidance is around $250,000 per unit (mid-high $50MM’s).  Owned by CBRE Global Investors and managed by Greystar.  A few highlights are below:
 
•	Excellent value-add opportunity 
•	The 51 (23%) of fully upgraded Aster units currently lease for about $275 above the classics
•	Rents of nearby competitive properties and Buckhead high-rises have created $300-$900 of headroom
•	Walkable to Buckhead Village district in just 10 minutes – one of the only wood-framed assets that can make this claim
•	Well below replacement cost for the area"',TRUE,TRUE,''),
('Carmel Vista','6 - Passed','Atlanta, GA',228,2021,263157,60000000,NULL,'2021-08-05','2021-08-23','all docs saved
I don’t think we’ve connected on Carmel Vista? Pricing is low to mid $260,000/unit. Average rent on the rent roll is $1,530 but rents today are over $1700. There’s a 106 bp increase in Year 1 yield attributable to lease trade-outs making the EOY cap 4.75%.
 
Quick Notes:
 
1.	This has been the most successful development in Vista’s 30-year history
2.	Leased up in 4-months, most months over 50 leases
3.	Increased rents weekly but couldn’t find a rent ceiling until all units were leased
4.	Leased so quickly they were 90% leased but only 40% occupied.
5.	20% of the units were leased before any units were delivered. 
4.	Concessions stopped in month two of the lease up
5.	Nearby Canyon Springs was just sold at $275,000/unit. Rents are over $1800.
6.	Similar rents for an asset on Northside of town equates to over $315,000/unit.',FALSE,TRUE,''),
('NorthHaven at Johns Creek','6 - Passed','Atlanta, GA',227,1999,317180,72000000,'2021-08-18','2021-07-12','2021-08-18','all docs saved
The property should trade in +/- $72M range (approximately, in place (adjusted for taxes and reserves) cap rate of 4% - with the following notables attributes: 
* Johns Creek has NO MF supply, last property built in 2013
* Largest unit size: 1224 Average
* Top schools and most affluent suburb in Atlanta – Resident HHI: $110k+; Top 10% schools
* Axiometrics Rent Growth Projections: 4%+/year
* Recent $18,000/unit renovations with Light Value Add Remaining:   Washers/Dryers; Faux wood vinyl floor; fenced in yards - $250,000 rental income growth
* Taxes are frozen for the next 2 years, saving $320,000/year (taking the cap rate to 4.4%)',TRUE,TRUE,''),
('The Waterford Apartments','6 - Passed','Raleigh-Durham-Chapel Hill, NC',300,2000,215000,64500000,'2021-08-11','2021-07-20','2021-08-17','all docs saved
NW Raleigh, near lake crabtree, RTP, airport etc
interior focused value-add (clubhouse, roofs, landscaping etc. all done last year)',TRUE,TRUE,''),
('Highlands at Alexander Pointe','6 - Passed','Charlotte-Gastonia-Rock Hill, NC-SC',309,2002,245954,76000000,'2021-08-03','2021-07-07','2021-08-05','all docs saved

To help guide your initial review, please see below for pricing guidance and other key offering details: 
-	Pricing guidance in the $240s/u, which is low $200s PSF (mid-to-high $70Ms total deal size)
-	4% in-place cap rate / 3.75% tax adjusted cap rate (next revaluation not until 2023)
-	Offers likely due the last week of July

Differentiated Asset Primed for Value-Add in Charlotte’s University City
-	Property Website | Highlands at Alexander Pointe 
-	2002 construction, 309 units, avg size of 1,162 SF, 96.8% occupied, avg in-place rent $1,271| $1.09
-	Differentiated features include: private, ground floor entryways (100% of units); attached garages (82% of units); 2BR townhomes (90 units / 29% of units).
-	Convenient access to I-485/I-85 interchange (1.8 miles north) and JW Clay Blvd Light Rail Station (1.5 miles south)
-	Since May 2020, the property has maintained an average physical occupancy of 95.2% and experienced effective rent growth of 6.6%.  

Value-Add Upside
-	Current renovation scope (39.5% of units): 116 units partially renovated; 6 units renovated
-	+$200 headroom to newer construction in the submarket 
-	Current ownership has spent $560K since 2019 on site and community improvements
-	Opportunity to enhance amenities, rebrand and paint exteriors to maximize additional value-add upside

Robust Multifamily Submarket with Notable Fundamentals
-	Over the past 5 years, the University City submarket has outperformed the overall Charlotte MSA
-	Cumulative effective rent growth of 29.4% (5.28% CAGR) and 95.3% avg physical occupancy (University submarket)

Positioned in Flourishing University City, Charlotte’s “Tech” Office Submarket
-	Charlotte’s second largest employment node – 75,000+ employees and 23 regional offices of Fortune 500 companies
-	$1B economic announcement from Centene in 2020, brining 6,000 new jobs with $100k incomes within 2 miles of the property',TRUE,TRUE,''),
('The Townhomes at Woodmill Creek','6 - Passed','Houston, TX',171,2016,292397,50000000,'2021-08-03','2021-07-30','2021-08-05','all docs saved
51.5M pricing based on debt model from Elliott, talking to Dustin Selzer 8/2
"$50mm is guidance on Townhomes"',TRUE,FALSE,''),
('The Flats at West Broad Village','6 - Passed','Richmond-Petersburg, VA',339,2009,294985,100000000,'2021-08-11','2021-07-07','2021-08-02','all docs saved

We are targeting pricing in the $100m range for the deal which shakes out to be a low-4.0% cap rate on proforma.  The property has proven out a strong value-add strategy at the property and is achieving $200+ premiums.  The owner has also recently opened a 9k SF newly completed amenity space with a $1.2m fit out that is lights out.  They haven''t had the benefit of leasing with the new amenity space and we think that you can push the rental premiums to $200 per unit.  Additionally, the rental growth projections for the market & submarket are consistently in the mid- to high- single digits over the next 5+ years.  We are getting to mid-teens returns regardless of the execution scenario on the deal.  The property was built in 2009 with 9'' ceiling and is currently 95% occupied.  Irreplaceable Short Pump location in Richmond within walking distance of Whole Foods.  Let me know what your interest level is and if you''d like to schedule a call to discuss.',TRUE,TRUE,''),
('The Vinings at Hunters Green','6 - Passed','Tampa-St. Petersburg-Clearwater, FL',240,1995,204166,49000000,'2021-08-05','2021-07-12','2021-08-02','all docs saved
At $49M, T3 Inc - T12 Exp (tax adj at 85%) = ~3.75% cap

OM says 75-80% so can check with Ryan – maybe this has gone down a little.  Used to be more around 85%.

Kind of out there, but seems like a pretty nice area – very good demographics (income and home values).

Value-add:
-	add Washer and dryer in all units (all have connections)
-	57% classic units
-	41% partially renovated units
-	2% fully upgraded

Looks like need to do a little work on common area and amenities.  All new roofs in 2016...',FALSE,TRUE,''),
('Indigo Apartments','6 - Passed','Raleigh-Durham-Chapel Hill, NC',489,2005,210000,102690000,'2021-07-27','2021-07-12','2021-08-02','all docs saved',FALSE,TRUE,''),
('Linden on the GreeneWay','6 - Passed','Orlando, FL',234,2017,256410,60000000,NULL,'2021-07-23','2021-08-02','all docs saved
good location - lots of healthcare and industrial jobs nearby
does not look like much value-add potential (interior: backsplash and other light touches, exterior: add outdoor kitchen and playground)',FALSE,TRUE,''),
('Thornblade Park Apartments','6 - Passed','Greenville-Spartanburg-Anderson, SC',293,1997,184300,54000000,'2021-08-03','2021-07-12','2021-08-02','all docs saved
"We expect competitive initial offers in the mid $50Ms, or mid $180Ks per unit, translating to a ~4% cap on in-place (tax-adjusted) financials."
We are likely to call for offers the first week of August.  Below are a few quick highlights, along with pricing guidance:

Rent Growth and Value-Add Upside:   Thornblade Park offers a full value-add platform: 100% of units have upside potential and over 80% of units are in either ‘classic’ or and older ‘partially renovated’ condition.  Total weighted rent premiums of nearly $200 per month across the entire property are achievable and well-supported, in addition to ancillary washer-dryer installations and amenity enhancements. The property is also demonstrating strong organic rent growth, with an average 4.3% increase in lease trade-outs over the trailing three months.  

Highly Affluent, Ultra High-Barrier Location: Thornblade Park is located in an affluent, infill neighborhood with average HHI well above $100,000 and neighboring home values exceeding $1M.  There is little room for new construction in this infill pocket, with only one new apartment development delivered in the past 13 years.

Desirable Employment Access and Schools: Thornblade Park is walkable to Michelin North America’s headquarters and is within a five-mile drive of over 80,000 jobs.  The community also offers residents with children access to the most desirable schools in the Upstate, including Woodland Elementary, which achieved Palmetto’s Finest Award in 2019-2020.',FALSE,TRUE,''),
('The Dunhill Design District','6 - Passed','Dallas-Fort Worth, TX',214,2008,233644,50000000,NULL,'2021-07-27','2021-08-02','from ZOM
OM saved
Loan Assumption - about 7 yrs remaining at 4.25%, no IO',TRUE,TRUE,''),
('Quarterside Uptown Apartments','6 - Passed','Charlotte-Gastonia-Rock Hill, NC-SC',184,2008,295000,54280000,'2021-07-28','2021-07-07','2021-08-02','all docs saved
"Expecting 290-300k/door range"',FALSE,TRUE,''),
('Northwoods Townhomes','6 - Passed','Raleigh-Durham-Chapel Hill, NC',137,1998,NULL,NULL,'2021-07-29','2021-07-07','2021-07-26','all docs saved',FALSE,TRUE,''),
('The Mark Apartments','6 - Passed','Washington, DC-MD-VA',227,1965,233480,53000000,'2021-07-27','2021-06-16','2021-07-26','all docs saved
Guidance is $48-50MM if you assume the loan (approx. $220K per unit) and $55+MM on a free and clear basis.
Per Tour sounded like low/mid 50s...55M is goal',FALSE,TRUE,''),
('Salado Springs Apartments','6 - Passed','San Antonio, TX',352,1997,130681,46000000,NULL,'2021-07-19','2021-07-26','all docs saved
N SA, looks like nice location, 20% renovated for $140 prem',FALSE,TRUE,''),
('Legacy Heights Luxury Apartment Homes','6 - Passed','San Antonio, TX',306,2009,174836,53500000,NULL,'2021-07-23','2021-07-26','NO OM 7/23
N SA near Alamo Heights and Terrell Hills - looks like a good location, 2009 vintage, light value add - stainless appliances, vinyl flooring etc',FALSE,TRUE,''),
('Marquis at Stone Oak','6 - Passed','San Antonio, TX',335,2007,238805,80000000,NULL,'2021-07-07','2021-07-26','all docs saved
great demographics, very far N SA, next to golf course and nice SF, light value-add, very large units, nice comparison to comps
SUGGESTED UPGRADES
u Upgrade Classic Units
(121 Units, Projected $250 Premiums)
u Upgrade Partially Renovated Units
(123 Units, Projected $75 Premiums)
u Upgrade Presidential Units
(91 Units, Projected $75 Premiums)
u Add Washer/Dryer Equipment
(All Units, Projected $45 Premiums)
u Add Private Yards
(21 Units, Projected $150 Premiums)',FALSE,TRUE,''),
('Arbors at Maitland Apartments','6 - Passed','Orlando, FL',663,1998,226244,150000000,NULL,'2021-07-12','2021-07-26','all docs saved
too big, but nice looking deal in good location, maybe could work for US LP?',FALSE,TRUE,''),
('Savannah at Park Central Apartments','6 - Passed','Orlando, FL',288,2007,NULL,NULL,NULL,'2021-07-07','2021-07-26','all docs saved
near millinea',FALSE,TRUE,''),
('Villas at Palm Bay','6 - Passed','Melbourne-Titusville-Palm Bay, FL',160,2007,171875,27500000,NULL,'2021-07-19','2021-07-26','all docs saved 
"Around $27 - $28 million
CFO in like 2 week probably setting it this week (7/26"',FALSE,TRUE,''),
('Shoreview Flats','6 - Passed','Dallas-Fort Worth, TX',235,2020,242553,57000000,NULL,'2021-07-12','2021-07-26','all docs saved - curious to see how something like this is priced...looks like ok location within white rock lake...
"We are whispering low $240K/door"',FALSE,TRUE,''),
('Stella at Shadow Creek Ranch','6 - Passed','Brazoria, TX',392,2008,NULL,NULL,NULL,'2021-07-23','2021-07-26','all docs saved
S Houston, masterplan community, look like a good area on map, good retail and office parks nearby',FALSE,TRUE,''),
('Dawson Forest Apartments','6 - Passed','',268,1998,NULL,NULL,NULL,'2021-07-23','2021-07-26','PORTFOLIO all docs saved',FALSE,TRUE,''),
('Rosemont City View','6 - Passed','Atlanta, GA',320,1986,NULL,NULL,NULL,'2021-07-23','2021-07-26','PORTFOLIO 
all docs saved',FALSE,TRUE,''),
('Enclave at Roswell','6 - Passed','Atlanta, GA',236,1985,167372,39500000,'2021-08-02','2021-07-12','2021-07-26','all docs saved
"Enclave will trade about $165-$170k/unit"',FALSE,TRUE,''),
('Alexander at the District','6 - Passed','Atlanta, GA',280,2007,NULL,NULL,NULL,'2021-06-16','2021-07-26','all docs saved',FALSE,TRUE,''),
('ARIUM Station 29','6 - Passed','Atlanta, GA',217,2002,184331,40000000,'2021-04-21','2021-04-02','2021-07-26','part of portfolio with Arium Dunwoody',TRUE,TRUE,''),
('Rockview Apartments','6 - Passed','Washington, DC-MD-VA',89,1955,NULL,NULL,NULL,'2021-04-20','2021-07-26','all docs in folder
model v1 done',TRUE,FALSE,''),
('Key Bridge Marriott','6 - Passed','Washington, DC-MD-VA',300,NULL,NULL,NULL,NULL,'2021-06-16','2021-07-23','all docs saved
just put on here for fun',FALSE,TRUE,''),
('The Aventine Greenville','6 - Passed','Greenville-Spartanburg-Anderson, SC',346,2013,175000,60550000,'2021-07-22','2021-07-07','2021-07-23','all docs saved

Off Market

Our team has been engaged to market The Aventine in Greenville, SC to a limited group of investors. The 346-unit garden asset was built in 2013 and is owned by Gamma RE based in New York. The property has been institutionally maintained for the last 8 years, previously owned by IRT. Current ownership has invested over $1 million into the asset, consisting of full exterior paint, clubhouse and fitness center renovation, and 39 unit renovations. The current unit renovations are yielding $100-$200 rent premiums, leaving a true value opportunity for the next owner on the remaining 307 units (89% of property).

 

The Aventine is in the heart of Greenville’s innovation employment district, along interstates 385 and 85, and is walkable to Whole Foods Market.

 

The property can be purchased free and clear or with the existing debt (Fannie, UPB: $35,095,000, 4.70%, full term interest only until a 1/1/29 maturity date).

 

Guidance:

Free and clear: north of $200k/unit
Debt assumption: $175k/unit
 

Process:

We will conduct site tours over the next few weeks on Tuesday’s and Wednesday’s and likely call for offers on July 22nd to allow for vacations over the July 4th holiday
Please reach out to Hallie Schellhorn (hschellhorn@northmarq.com ) to schedule tours & handle CAs and direct underwriting questions to Austin Jackson (apjackson@northmarq.com)
Please contact Andrea Howard (704-756-7485) or John Currin (919-357-7751) to discuss the deal
Property information is housed in a Box link that you will be provided access to once the attached CA is signed and returned',FALSE,TRUE,''),
('Village of Churchills Choice','6 - Passed','Washington, DC-MD-VA',192,2000,NULL,NULL,NULL,'2021-07-07','2021-07-20','all docs saved',FALSE,TRUE,''),
('Castle Hills Townhomes','6 - Passed','San Antonio, TX',148,1999,NULL,NULL,NULL,'2021-05-24','2021-07-20','north SA, TH style, value-add, maybe too small?
coming soon, no docs yet 6/9',FALSE,TRUE,''),
('Viceroy Apartments','6 - Passed','Fort Worth, TX',248,1998,NULL,NULL,NULL,'2021-05-24','2021-07-20','1998 built value-add in FW, continue or expand current VA program
all docs in folder',FALSE,TRUE,''),
('Alexis at Town East Apartment Homes','6 - Passed','Dallas-Fort Worth, TX',224,2002,165000,36960000,'2021-07-14','2021-06-16','2021-07-19','all docs saved
see notes below - talked to Collins Thompson 6/9
$165/unit (just under $37M) – should be around a 4% cap – (well under $200/unit replacement cost)
2002 built, new roofs in 2017, clubhouse renovation in 2017
Owned by TIC (26 owners) – can’t pre-emt, 2-3 weeks to sign PSA / get access, so could work well timing wise – they have owned for 8 years and JMG Management is third-party manager
99% occupied
Value add: (87% of units are untouched)
$175 prem for moderate renovation – basically everything but granite – blue collar market so don’t want to overdo it
77 ground floor units – add private backyard ~$150 premium
Comps - Mission Ranch and The Barrons (top comp – a little newer but rents are $100 higher)
Mesquite:
Eastern side of Dallas
Similar to Garland
Blue Collar – service industry
Good cost of living and schools, quiet',FALSE,TRUE,''),
('Autumn Woods','6 - Passed','Raleigh-Durham-Chapel Hill, NC',236,1997,207500,48970000,'2021-07-14','2021-06-16','2021-07-19','all docs saved
$205-210k/door. CFO likely mid to late July.',FALSE,TRUE,''),
('The District at Medical Center','6 - Passed','San Antonio, TX',303,2015,NULL,NULL,'2021-07-19','2021-06-16','2021-07-19','all docs saved - NO OM 6/16',FALSE,TRUE,''),
('Waterford Park Apartments','6 - Passed','San Antonio, TX',224,2008,NULL,NULL,'2021-07-14','2021-06-16','2021-07-19','docs saved - NO OM 6/16
NE side of SA',FALSE,TRUE,''),
('Savannah Midtown','6 - Passed','Atlanta, GA',322,2000,NULL,NULL,'2021-07-15','2021-06-16','2021-07-19','all docs saved',FALSE,TRUE,''),
('The Highline Apartment Homes','6 - Passed','San Antonio, TX',208,2000,NULL,NULL,'2021-07-13','2021-06-16','2021-07-19','all docs saved',FALSE,TRUE,''),
('The Lofts at Midtown','6 - Passed','Raleigh-Durham-Chapel Hill, NC',183,1974,NULL,NULL,NULL,'2021-04-27','2021-07-07','Off Market
Abstract of loan terms is below with the Note attached for more detail.  Prepay is 1% after it opens up next year.  Please reach out with any questions.
•	Current Balance: $21,650,000
•	Interest Rate: Floating based on attached
•	Maturity Date: 1/1/2031
•	I/O: 5 Years, 30 year amortizing after
all docs in folder',FALSE,TRUE,''),
('The Greens at Tryon Apartments','6 - Passed','Raleigh-Durham-Chapel Hill, NC',264,2001,NULL,NULL,'2021-06-30','2021-06-16','2021-07-06','all docs saved',FALSE,TRUE,''),
('Oxford Georgetown','6 - Passed','Washington, DC-MD-VA',217,NULL,NULL,NULL,'2021-06-29','2021-05-24','2021-07-06','New construction under development in Georgetown
docs in folder',FALSE,TRUE,''),
('ARIUM Mt. Pleasant','6 - Passed','Charleston-North Charleston, SC',240,1983,242500,58200000,'2021-06-30','2021-06-16','2021-07-06','all docs saved
low $240ks/unit',FALSE,TRUE,''),
('Earle Manor Apartments','6 - Passed','Washington, DC-MD-VA',140,1960,NULL,NULL,'2021-06-22','2021-05-24','2021-07-06','all docs saved
owned by Blackfin and Acre Valley, we bid on this a few yrs ago',FALSE,TRUE,''),
('The Hyde Park Urban Portfolio','6 - Passed','Tampa-St. Petersburg-Clearwater, FL',241,NULL,NULL,NULL,'2021-06-24','2021-05-21','2021-07-06','all docs saved
11 properties',FALSE,TRUE,''),
('Greens at Hollymead Apartments','6 - Passed','Charlottesville, VA',144,1991,NULL,NULL,NULL,'2021-05-21','2021-06-21','all docs saved',FALSE,TRUE,''),
('The Point at Park Station','6 - Passed','Washington, DC-MD-VA',350,2004,NULL,NULL,'2021-06-17','2021-05-21','2021-06-21','all docs saved',FALSE,TRUE,''),
('The Point at Seven Oaks','6 - Passed','Baltimore, MD',264,2000,NULL,NULL,'2021-06-17','2021-05-21','2021-06-21','all docs saved',FALSE,TRUE,''),
('Wisper Palms Apartment Homes','6 - Passed','Orlando, FL',308,2004,201298,62000000,NULL,'2021-04-13','2021-06-21','see notes on teams.  per last conversation with Chip: looking into options with SF, still in lockout period and assumption is not allowed, should have more info in next 30-45 days (as of early June).',TRUE,TRUE,''),
('Pointe At Chapel Hill','6 - Passed','Raleigh-Durham-Chapel Hill, NC',240,2000,NULL,NULL,'2021-06-16','2021-03-24','2021-06-16','passed on this off market, now on market, OM in folder',TRUE,TRUE,''),
('Haven at Westover Hills','6 - Passed','San Antonio, TX',326,2005,NULL,NULL,'2021-06-15','2021-05-24','2021-06-15','west side of SA, looks like touristy area next to SeaWorld SA,  light VA, vinyl backsplash etc for 100 prem
all docs in folder',FALSE,TRUE,''),
('The Estates at Canyon Ridge','6 - Passed','San Antonio, TX',270,2007,192592,52000000,'2021-06-15','2021-05-24','2021-06-15','north SA, big house design (attached garages, lives like TH), 17 renovated units, OM pitches 125 prem, decent mount of work to do based on pics
all docs in folder
Pricing 190s, 195 is their aspirational target',FALSE,TRUE,''),
('Tapestry at Hollingsworth Park','6 - Passed','Greenville-Spartanburg-Anderson, SC',242,2013,194214,47000000,NULL,'2021-06-09','2021-06-11','all docs in folder
Guiding mid 190s per unit on all cash and $180k per unit on the assumption
Pre-empted',FALSE,TRUE,''),
('Trailside Verdae','6 - Passed','Greenville-Spartanburg-Anderson, SC',276,2020,225000,62100000,'2021-06-09','2021-05-21','2021-06-11','all docs in folder',FALSE,TRUE,''),
('Bella Madera','6 - Passed','San Antonio, TX',328,2007,NULL,NULL,NULL,'2021-04-27','2021-06-09','good size and vintage, near the west oaks deal, ZRS manages something nearby
all docs in folder',FALSE,TRUE,''),
('The Heights Apartments','6 - Passed','Fort Worth, TX',246,1996,NULL,NULL,NULL,'2021-04-18','2021-06-09','',FALSE,TRUE,''),
('Willowbrook Apartments','6 - Passed','Greenville-Spartanburg-Anderson, SC',144,2000,152777,22000000,NULL,'2021-04-18','2021-06-09','Off Market
See email from John',FALSE,TRUE,''),
('AMLI Memorial Heights','6 - Passed','Houston, TX',380,2002,NULL,NULL,NULL,'2021-04-26','2021-06-09','No OM yet',FALSE,TRUE,''),
('Vista at Plum Creek','6 - Passed','Austin-San Marcos, TX',264,2010,NULL,NULL,NULL,'2021-04-27','2021-06-09','Waiting for access to war room',FALSE,TRUE,''),
('Williamsburg Manor Apartments & Townhomes of Cary','6 - Passed','Raleigh-Durham-Chapel Hill, NC',183,1971,NULL,NULL,NULL,'2021-04-27','2021-06-09','',FALSE,TRUE,''),
('Kingston Villas Apartments','6 - Passed','Houston, TX',430,2000,NULL,NULL,NULL,'2021-04-27','2021-06-09','',FALSE,TRUE,''),
('AMLI City Vista','6 - Passed','Houston, TX',404,2008,NULL,NULL,'2021-05-26','2021-05-03','2021-06-09','',FALSE,TRUE,''),
('Shadow Ridge Apartments','6 - Passed','Atlanta, GA',294,2000,NULL,NULL,'2021-05-19','2021-05-03','2021-06-09','',FALSE,TRUE,''),
('Mosby University City','6 - Passed','Charlotte-Gastonia-Rock Hill, NC-SC',309,2020,NULL,NULL,'2021-06-03','2021-04-19','2021-06-08','all docs saved',TRUE,TRUE,''),
('V & Three Apartment Homes','6 - Passed','Charlotte-Gastonia-Rock Hill, NC-SC',338,2019,NULL,NULL,'2021-05-26','2021-04-18','2021-06-08','',TRUE,TRUE,''),
('Six Forks Station Apartments','6 - Passed','Raleigh-Durham-Chapel Hill, NC',323,1986,NULL,NULL,'2021-06-02','2021-05-03','2021-06-08','',FALSE,TRUE,''),
('Rustico At Fair Oaks Apartments','6 - Passed','San Antonio, TX',292,2017,NULL,NULL,'2021-06-03','2021-04-18','2021-06-08','waiting for access to war room',FALSE,TRUE,''),
('Adara Herndon','6 - Passed','Washington, DC-MD-VA',392,2000,NULL,NULL,'2021-06-03','2021-05-03','2021-06-08','all docs in folder',FALSE,TRUE,''),
('Alexan Winter Park','6 - Passed','Orlando, FL',310,2020,NULL,NULL,NULL,'2021-04-06','2021-05-24','waiting for access to war room
nice location but new, nothing to do, so probably not for us',FALSE,TRUE,''),
('The Estates at Crossroads','6 - Passed','Atlanta, GA',344,2002,215116,74000000,'2021-04-29','2021-04-12','2021-05-24','Passco owned, waiting on info from Derrick

210-220k/unit',TRUE,TRUE,''),
('Hawthorne at Sugarloaf','6 - Passed','Atlanta, GA',260,2007,200000,52000000,'2021-04-28','2021-03-18','2021-05-24','high quality product w interior Reno upside, but requires loan assumption',TRUE,FALSE,''),
('Loretto at Creekside','6 - Passed','San Antonio, TX',320,2017,162500,52000000,'2021-05-13','2021-04-14','2021-05-24','',TRUE,TRUE,''),
('The Bristol Apartment Homes','6 - Passed','Greenville-Spartanburg-Anderson, SC',258,1971,162790,42000000,'2021-05-04','2021-04-12','2021-05-24','I like this one a lot, see notes on teams, low to mid 160s/unit',FALSE,TRUE,''),
('Jefferson Westshore','6 - Passed','Tampa-St. Petersburg-Clearwater, FL',246,2014,264227,65000000,'2021-04-27','2021-01-26','2021-05-24','',TRUE,TRUE,''),
('Sorrel Grand Parkway Apartments','6 - Passed','Houston, TX',380,2014,194736,74000000,'2021-05-12','2021-04-19','2021-05-24','',TRUE,TRUE,''),
('Centerview at Crossroads Apartments','6 - Passed','Raleigh-Durham-Chapel Hill, NC',374,2008,229946,86000000,'2021-05-12','2021-04-18','2021-05-24','',TRUE,TRUE,''),
('West Oaks Luxury Apartments','6 - Passed','San Antonio, TX',352,2012,130000,45760000,'2021-04-20','2021-04-12','2021-05-24','looks like good location / nearby retail, 2012 built untouched, looks like room between newer nearby comps, OM pitches adding vinyl flooring and ss apps - 4.26cap T12, 4.5cap PF, very low basis/unit',FALSE,TRUE,''),
('Olympus at Ross','6 - Passed','Dallas-Fort Worth, TX',368,2015,202500,74520000,'2021-04-29','2021-04-06','2021-05-24','nice location (dowtown) but does not look to have any upside, so probably not for us',FALSE,TRUE,''),
('The Club of the Isle','6 - Passed','Galveston-Texas City, TX',264,2004,181818,48000000,'2021-05-11','2021-04-19','2021-05-24','47-49M, 1hr SE of Houston on Galveston Island',FALSE,TRUE,''),
('Hill House Apartment Homes','6 - Passed','Philadelphia, PA-NJ',188,1964,335106,63000000,'2021-05-18','2021-04-18','2021-05-24','62-64M, great location, nice looking deal, talked to Erin sounded interesting.  Heavy reno in 2015, continue existing renos (I think maybe 30 left) and add w/d in units that can accommodate them.',FALSE,TRUE,''),
('Central Station on Orange','6 - Passed','Orlando, FL',279,2015,NULL,NULL,'2021-05-13','2021-04-20','2021-05-24','',FALSE,TRUE,''),
('Shoreview at Baldwin Park','6 - Passed','Orlando, FL',184,1970,138586,25500000,'2021-05-12','2021-04-07','2021-05-24','just outside of SE corner of Baldwin Park property, too old / not great location (wrong side of Baldwin Park if you are not in BP proper) 25-26M',FALSE,TRUE,''),
('Lakewood Greens Apartments','6 - Passed','Dallas-Fort Worth, TX',252,1986,178571,45000000,'2021-05-26','2021-04-20','2021-05-24','good delta to white rock lake villas but pretty small units',FALSE,TRUE,''),
('Tenison at White Rock','6 - Passed','Dallas-Fort Worth, TX',252,1985,158730,40000000,'2021-05-26','2021-04-20','2021-05-24','good delta to white rock lake villas but pretty small units',FALSE,TRUE,''),
('Vanguard Northlake Apartments','6 - Passed','Charlotte-Gastonia-Rock Hill, NC-SC',204,2015,NULL,NULL,NULL,'2021-04-18','2021-05-03','',FALSE,TRUE,''),
('ARIUM Dunwoody','6 - Passed','Atlanta, GA',227,1990,176211,40000000,'2021-04-21','2021-04-02','2021-04-26','Part of portfolio with Arium Station 29',TRUE,TRUE,''),
('7900 At Park Central Apartments','6 - Passed','Dallas-Fort Worth, TX',308,1998,172077,53000000,'2021-04-15','2021-04-01','2021-04-26','$53 mm cash to note, or $58 mm cash
looks interesting, total return not bad, but no cash flow with loan assumption',TRUE,FALSE,''),
('Vista Way Apartments','6 - Passed','Orlando, FL',468,1989,170000,79560000,NULL,'2021-04-12','2021-04-20','Vacant, was employee housing.  170/unit.  Too big, not great location.',FALSE,TRUE,''),
('Hidden Creek','6 - Passed','Atlanta, GA',116,1999,NULL,NULL,NULL,'2021-04-20','2021-04-20','',FALSE,TRUE,''),
('Wyndsor Court Apartments','6 - Passed','Dallas-Fort Worth, TX',280,1997,NULL,NULL,'2021-04-01','2021-04-01','2021-04-20','offers already due (4/1) just wanted to see OM / info on Allen market',FALSE,TRUE,''),
('Rialto','6 - Passed','Washington, DC-MD-VA',74,2021,472972,35000000,NULL,'2021-03-29','2021-04-20','Under construction CoO expected June 2021',FALSE,TRUE,''),
('The Summit at Metrowest Apartments','6 - Passed','Orlando, FL',280,1991,196428,55000000,'2021-04-22','2021-03-22','2021-04-20','',TRUE,TRUE,'')
ON CONFLICT (name) DO NOTHING;

INSERT INTO deals (name,status,market,units,year_built,price_per_unit,purchase_price,bid_due_date,added,modified,comments,flagged,hot,broker) VALUES
('Somerset At The Crossings Apartments','6 - Passed','Atlanta, GA',264,1987,155000,40920000,'2021-03-26','2021-03-18','2021-04-19','managed by BH, under-managed (?) w some upside

rougher buildings in questionable condition

would want to look at 2-3 yr in and out business plan here',TRUE,TRUE,''),
('The Peaks at Gainesville','6 - Passed','',292,2000,NULL,NULL,NULL,'2021-03-18','2021-04-19','built as LIHTC deal, out of compliance period, exterior resin and renovation finished, but units all original',TRUE,TRUE,''),
('The Legends at Champions Gate Apartments','6 - Passed','Lakeland-Winter Haven, FL',252,2002,NULL,NULL,'2021-04-16','2021-03-25','2021-04-19','',TRUE,TRUE,''),
('Villas at Park Avenue','6 - Passed','Savannah, GA',238,2014,NULL,NULL,'2021-04-22','2021-03-17','2021-04-19','',TRUE,TRUE,''),
('Huntington Apartments','6 - Passed','Raleigh-Durham-Chapel Hill, NC',212,1986,NULL,NULL,'2021-05-04','2021-04-01','2021-04-19','',TRUE,TRUE,''),
('Toledo Club Apartment Homes','6 - Passed','Sarasota-Bradenton, FL',348,2006,NULL,NULL,NULL,'2021-03-11','2021-04-19','',FALSE,TRUE,''),
('Tzadik Houston Portfolio','6 - Passed','Houston, TX',1275,1980,NULL,NULL,'2021-05-10','2021-04-19','2021-04-19','Airport Crossing (178 units ; 1983 built) ; Casa Grande (268 units ; 1979 built) ; Terrace at West Sam Houston (428 units ; 1979 built) ; Plaza at Hobby Airport (328 units ; 1976 built) ; The Townhomes (73 units ; 1981 built)',FALSE,TRUE,''),
('CityLine Park Apartments','6 - Passed','Dallas-Fort Worth, TX',435,2019,NULL,NULL,'2021-04-28','2021-04-01','2021-04-19','not for us, just wanted to read about Richardson market -JS',FALSE,TRUE,''),
('The Villages','6 - Passed','',72,2004,NULL,NULL,NULL,'2021-04-19','2021-04-19','waiting for access to war room',FALSE,TRUE,''),
('The Apartments at Harbor Park','6 - Passed','Washington, DC-MD-VA',190,1997,342105,65000000,'2021-04-16','2021-03-22','2021-04-19','PGIM is seller

4.1% in place cap',TRUE,TRUE,''),
('Villages of Chapel Hill','6 - Passed','Raleigh-Durham-Chapel Hill, NC',302,1974,NULL,NULL,'2021-04-29','2019-01-09','2021-04-18','',TRUE,TRUE,''),
('The Estates at Countryside Apartments','6 - Passed','Tampa-St. Petersburg-Clearwater, FL',320,1989,NULL,NULL,NULL,'2020-05-14','2021-04-14','',FALSE,TRUE,''),
('565 Hank','6 - Passed','Atlanta, GA',306,2021,NULL,NULL,'2021-04-21','2021-03-29','2021-04-12','Pre-Construction sale',FALSE,TRUE,''),
('Ruxton Towers Apartments','6 - Passed','Baltimore, MD',144,1964,NULL,NULL,'2021-04-27','2021-03-24','2021-04-12','',TRUE,FALSE,''),
('Noble Vines at Braselton','6 - Passed','Atlanta, GA',248,2020,NULL,NULL,'2021-05-05','2021-03-29','2021-04-12','"Coming Soon" no materials yet',FALSE,TRUE,''),
('The Residences At Congressional Village','6 - Passed','Washington, DC-MD-VA',403,2005,NULL,NULL,'2021-04-28','2021-03-25','2021-04-12','',FALSE,TRUE,''),
('Fusion Apartments','6 - Passed','Orlando, FL',192,1996,NULL,NULL,'2021-04-22','2021-03-22','2021-04-07','',FALSE,TRUE,''),
('Lofts at Eden','6 - Passed','Orlando, FL',175,2017,NULL,NULL,'2021-04-15','2021-03-22','2021-04-07','',FALSE,TRUE,''),
('Mainstreet at Conyers','6 - Passed','Atlanta, GA',192,2000,NULL,NULL,NULL,'2021-04-01','2021-04-07','',FALSE,TRUE,''),
('Belara Apartment Homes','6 - Passed','Atlanta, GA',182,1993,233516,42500000,NULL,'2021-03-09','2021-04-06','have to assume a loan per Kees ; $42-$43 MM range',TRUE,TRUE,''),
('Parc at 980','6 - Passed','Atlanta, GA',586,1996,NULL,NULL,'2021-04-21','2021-03-11','2021-04-06','',TRUE,TRUE,''),
('The Heritage at Settlers Landing','6 - Passed','Norfolk-Virginia Beach-Newport News, VA-NC',140,2007,NULL,NULL,'2021-04-22','2021-01-28','2021-04-06','was being marketed off market a while back',TRUE,TRUE,''),
('White Rock Lake Apartment Villas','6 - Passed','Dallas-Fort Worth, TX',296,1992,NULL,NULL,'2021-04-15','2021-03-17','2021-04-05','',TRUE,TRUE,''),
('Bridge Tower SFR','6 - Passed','Dallas-Fort Worth, TX',221,1997,NULL,NULL,NULL,'2021-03-22','2021-04-05','no OM but came with property photos folder',FALSE,TRUE,''),
('23Thirty Cobb Apartment Homes','6 - Passed','Atlanta, GA',222,1985,NULL,NULL,'2021-04-06','2021-03-11','2021-04-05','',FALSE,TRUE,''),
('Retreat at Crosstown Apartments','6 - Passed','Tampa-St. Petersburg-Clearwater, FL',320,1988,NULL,NULL,'2021-03-25','2021-03-25','2021-04-05','',FALSE,TRUE,''),
('Dunwoody Glen Apartment Homes','6 - Passed','Atlanta, GA',510,1972,NULL,NULL,'2021-04-14','2021-03-12','2021-04-05','"Coming Soon" no documents yet',FALSE,TRUE,''),
('The Mason','6 - Passed','Charleston-North Charleston, SC',264,2020,NULL,NULL,'2021-04-14','2021-03-10','2021-04-05','',FALSE,TRUE,''),
('Ascend Waterleigh','6 - Passed','Orlando, FL',354,2021,NULL,NULL,'2021-04-06','2021-03-25','2021-04-05','',FALSE,TRUE,''),
('Legacy Haywood Apartments','6 - Passed','Greenville-Spartanburg-Anderson, SC',244,2020,NULL,NULL,NULL,'2021-03-29','2021-04-01','',FALSE,TRUE,''),
('Parkside Vista Apartments','6 - Passed','Atlanta, GA',240,2008,214583,51500000,'2021-03-29','2021-02-24','2021-04-01','$51-$52M',TRUE,TRUE,''),
('Avana City North Apartments','6 - Passed','Atlanta, GA',357,2006,219887,78500000,NULL,'2021-03-18','2021-04-01','Greystar owned by norhtlake mall

originally built by Worthing',TRUE,TRUE,''),
('The Atlantic Sweetwater','6 - Passed','Atlanta, GA',200,1986,160000,32000000,'2021-03-24','2021-03-18','2021-03-29','under-rented for location; jv w LEM and Atlantic Pacific',TRUE,TRUE,''),
('YOO on the Park','6 - Passed','Atlanta, GA',242,2017,NULL,NULL,NULL,'2021-03-29','2021-03-29','No OM yet',FALSE,TRUE,''),
('Griffis Canyon Creek','6 - Passed','Austin-San Marcos, TX',296,2004,NULL,NULL,'2021-04-13','2021-03-22','2021-03-29','',FALSE,TRUE,''),
('The Oasis at West Melbourne Luxury Apartment Homes','6 - Passed','Melbourne-Titusville-Palm Bay, FL',316,2021,NULL,NULL,NULL,'2021-03-22','2021-03-24','RR and T12 but no OM yet',FALSE,TRUE,''),
('Caledon Apartments','6 - Passed','Greenville-Spartanburg-Anderson, SC',350,1995,152571,53400000,'2021-03-24','2021-02-24','2021-03-22','low 150s / dr - per John Munroe',TRUE,TRUE,''),
('The Ivy Residences at Health Village','6 - Passed','Orlando, FL',248,2015,240000,59520000,NULL,'2021-03-02','2021-03-22','$240k/door',TRUE,TRUE,''),
('Keystone at Castle Hills','6 - Passed','Dallas-Fort Worth, TX',690,1987,NULL,NULL,NULL,'2021-03-22','2021-03-22','Acre Valley''s deal
"Coming Soon" no materials yet',FALSE,TRUE,''),
('Tree Top Apartments','6 - Passed','Raleigh-Durham-Chapel Hill, NC',206,1972,NULL,NULL,'2021-04-06','2021-03-02','2021-03-22','',FALSE,TRUE,''),
('Bexley at Harborside Apartments','6 - Passed','Charlotte-Gastonia-Rock Hill, NC-SC',264,2005,NULL,NULL,'2021-04-06','2021-03-03','2021-03-22','part of portfolio with Bexley at Matthews',FALSE,TRUE,''),
('Bexley At Matthews','6 - Passed','Charlotte-Gastonia-Rock Hill, NC-SC',240,2001,NULL,NULL,'2021-04-06','2021-03-03','2021-03-22','part of portfolio with Bexley Harborside',FALSE,TRUE,''),
('The Madison','6 - Passed','Charlotte-Gastonia-Rock Hill, NC-SC',460,1987,179347,82500000,'2021-03-23','2021-02-11','2021-03-22','low 80Ms ; projected CFO mid-March per 2/16/21',FALSE,TRUE,''),
('2460 Peachtree Apartments','6 - Passed','Atlanta, GA',236,1984,233050,55000000,'2021-03-16','2021-02-08','2021-03-18','Mid $50M',TRUE,TRUE,''),
('Preserve at Woods Lake','6 - Passed','Greenville-Spartanburg-Anderson, SC',232,1997,147500,34220000,'2021-03-17','2021-02-11','2021-03-18','upper 140k''s per door',TRUE,TRUE,''),
('Residences at Shiloh Crossing','6 - Passed','Raleigh-Durham-Chapel Hill, NC',318,2021,NULL,NULL,NULL,'2021-02-24','2021-03-18','"coming soon" no documents yet',FALSE,TRUE,''),
('The Point at Germantown Station','6 - Passed','Washington, DC-MD-VA',468,1985,NULL,NULL,'2021-04-06','2021-02-24','2021-03-18','',FALSE,TRUE,''),
('Twenty25 Barrett','6 - Passed','Atlanta, GA',238,2014,256302,61000000,'2021-03-09','2021-01-12','2021-03-15','Owned by Passco

2.16: too expensive, high 3 cap on yr1, not much value add',TRUE,TRUE,''),
('Woodside Eleven','6 - Passed','Greenville-Spartanburg-Anderson, SC',200,2020,NULL,NULL,NULL,'2021-02-12','2021-03-15','',TRUE,TRUE,''),
('The Reserve at White Oak','6 - Passed','Raleigh-Durham-Chapel Hill, NC',248,2016,201612,50000000,'2021-03-11','2021-02-11','2021-03-10','"targeting $50MM and CFO likely to be around 2nd week of march" per 2/16/21',FALSE,TRUE,''),
('The Vineyard Apartments','6 - Passed','Austin-San Marcos, TX',468,2020,NULL,NULL,'2021-03-31','2020-12-16','2021-03-10','',TRUE,TRUE,''),
('Vantage at Powdersville','6 - Passed','Greenville-Spartanburg-Anderson, SC',288,2019,NULL,NULL,'2021-03-11','2021-03-02','2021-03-10','',FALSE,TRUE,''),
('Grace Apartment Homes','6 - Passed','Atlanta, GA',224,2005,157500,35280000,'2021-03-03','2021-02-11','2021-03-09','high 150s/door',FALSE,TRUE,''),
('Savannah Midtown','6 - Passed','Atlanta, GA',322,2001,220000,70840000,'2021-03-03','2021-01-13','2021-03-09','220k/unit ; ZRS likes and is putting together rent comps, need to correct hallways and elevators, large nice units, large roofdeck wasted space, lots of potential

2.16: arch going tomorrow, if that goes well need to fine tune model',TRUE,TRUE,''),
('Lewis House','6 - Passed','Atlanta, GA',132,2021,NULL,NULL,NULL,'2021-02-24','2021-03-09','waiting for access to war room',FALSE,TRUE,''),
('Viera Cool Springs','6 - Passed','Nashville, TN',468,1987,NULL,NULL,NULL,'2021-03-02','2021-03-09','RR & T12 but no OM yet',FALSE,TRUE,''),
('Boardwalk at Morris Bridge','6 - Passed','Tampa-St. Petersburg-Clearwater, FL',146,2001,NULL,NULL,NULL,'2021-02-24','2021-03-09','',FALSE,TRUE,''),
('Siena Park Apartments','6 - Passed','Washington, DC-MD-VA',188,2010,NULL,NULL,'2021-03-18','2021-02-24','2021-03-09','',FALSE,TRUE,''),
('Windsor at Contee Crossing','6 - Passed','Washington, DC-MD-VA',452,2008,294247,133000000,'2021-03-18','2021-02-08','2021-03-08','$133M',FALSE,TRUE,''),
('Modera Buckhead','6 - Passed','Atlanta, GA',399,2019,NULL,NULL,'2021-03-18','2021-02-11','2021-03-08','emailed for pricing and CFO 2/16/21',FALSE,TRUE,''),
('Garden District Apartment Homes','6 - Passed','Greenville-Spartanburg-Anderson, SC',223,NULL,NULL,NULL,NULL,'2021-02-23','2021-03-02','',FALSE,TRUE,''),
('Legacy at Norcross','6 - Passed','Atlanta, GA',100,1985,NULL,NULL,'2021-03-18','2021-02-24','2021-03-02','part of portfolio with Legacy at Lanier',FALSE,TRUE,''),
('Crest Gateway Apartments','6 - Passed','Charlotte-Gastonia-Rock Hill, NC-SC',40,2012,250000,10000000,'2021-02-22','2021-01-26','2021-03-02','245-255k/unit ; part of portfolio with Crest at Galleria and Crest at Greylyn (can be bough separately or as portfolio)',FALSE,TRUE,''),
('Carrington Chase Apartments','6 - Passed','Atlanta, GA',410,1986,137500,56375000,'2021-02-24','2021-02-11','2021-03-02','135-140/unit',FALSE,TRUE,''),
('Carrington Court Apartments','6 - Passed','Atlanta, GA',446,1988,137500,61325000,'2021-02-24','2021-02-11','2021-03-02','135-140/unit',FALSE,TRUE,''),
('The Centre at Peachtree Corners Apartments','6 - Passed','Atlanta, GA',272,1972,165000,44880000,'2021-03-04','2021-02-11','2021-03-02','160-170/unit',FALSE,TRUE,''),
('Modera Fairfax Ridge','6 - Passed','Washington, DC-MD-VA',213,2015,340375,72500000,'2021-03-18','2021-02-08','2021-03-02','low 70MM range ; early to mid march CFO per 2/16/21',FALSE,TRUE,''),
('Legacy at Lanier','6 - Passed','',150,2004,NULL,NULL,'2021-03-18','2021-02-24','2021-03-02','part of portfolio with Legacy at Norcross',FALSE,TRUE,''),
('Westlake Apartment Homes','6 - Passed','Orlando, FL',379,2001,NULL,NULL,NULL,'2021-01-22','2021-03-02','emailed for pricing 1/22/21 ; followed up 1/27/21 ; followed up on pricing 2/16/21 ; CFO likely 2-3 weeks out per 2/11/21',TRUE,TRUE,''),
('Crest at Greylyn Apartments','6 - Passed','Charlotte-Gastonia-Rock Hill, NC-SC',259,2013,225000,58275000,'2021-02-22','2021-01-26','2021-03-02','220-230k/unit ; part of portfolio with Crest at Galleria and Crest Gateway (can be bough separately or as portfolio)',TRUE,TRUE,''),
('The Crest at Galleria Apartments','6 - Passed','Charlotte-Gastonia-Rock Hill, NC-SC',48,2005,185000,8880000,'2021-02-22','2021-01-26','2021-03-02','180-190k/unit ; part of portfolio with Crest at Greylyn and Crest Gateway (can be bough separately or as portfolio)',FALSE,TRUE,''),
('Bungalow Walk at Lakewood Ranch','6 - Passed','',228,NULL,NULL,NULL,'2021-03-16','2021-02-11','2021-03-01','emailed for pricing 2/16/21',FALSE,TRUE,''),
('Ravens Crest Apartments','6 - Passed','Washington, DC-MD-VA',444,1989,247747,110000000,'2021-03-11','2021-02-11','2021-03-01','~110MM ; CFO likely 2nd week in march per 2/16/21',FALSE,TRUE,''),
('Vinings Palisades Apartments','6 - Passed','Atlanta, GA',427,1974,165000,70455000,'2021-03-10','2021-02-11','2021-02-26','$160s/unit',FALSE,TRUE,''),
('Heather Ridge Apartments','6 - Passed','Washington, DC-MD-VA',324,1988,262345,85000000,'2021-03-11','2021-02-11','2021-02-25','emailed for pricing and CFO 2/16/21',FALSE,TRUE,''),
('Fairway Apartments Reston','6 - Passed','Washington, DC-MD-VA',346,1969,271676,94000000,'2021-02-16','2021-01-15','2021-02-25','emailed for pricing 1/15/21 ; followed up 1/27/21 ; followed up 2/1/21',FALSE,TRUE,''),
('The Pearl Apartments','6 - Passed','Tampa-St. Petersburg-Clearwater, FL',314,2018,366242,115000000,'2021-03-09','2021-02-01','2021-02-24','low 4 cap ; PP comes from Yr1 OM proforma / 4.25%',FALSE,TRUE,''),
('Alexan Earl','6 - Passed','Washington, DC-MD-VA',333,2021,585585,195000000,'2021-03-09','2021-02-08','2021-02-24','190-200M ; 4.5% cap once stabilized',FALSE,TRUE,''),
('Urbon Apartment Homes','6 - Passed','Orlando, FL',361,2020,NULL,NULL,'2021-03-03','2021-01-14','2021-02-23','emailed for pricing 1/14/21 ; followed up 1/25/21',FALSE,TRUE,''),
('Carrington Park At Gulf Pointe','6 - Passed','Houston, TX',258,2007,NULL,NULL,'2021-02-24','2020-10-29','2021-02-23','',TRUE,TRUE,''),
('The Reserve at Campbells Creek Apartments','6 - Passed','Charlotte-Gastonia-Rock Hill, NC-SC',80,1982,125000,10000000,'2021-03-09','2021-01-26','2021-02-23','125k/door ; being sold in a portfolio with Stone Gate Apartments ; no materials yet ;  (can be bough separately or as portfolio)',FALSE,TRUE,''),
('Stone Gate Apartments','6 - Passed','Charlotte-Gastonia-Rock Hill, NC-SC',144,2000,135000,19440000,'2021-03-09','2021-01-26','2021-02-23','135k/door ; being sold in a portfolio with Reserve at Campbell''s Creek ; no materials yet; (can be bough separately or as portfolio)',FALSE,TRUE,''),
('Veere Apartments','6 - Passed','Orlando, FL',250,2020,266000,66500000,'2021-03-11','2021-02-08','2021-02-23','$66-67M',FALSE,TRUE,''),
('Satori Apartments','6 - Passed','Fort Lauderdale-Hollywood, FL',279,2009,336469,93875000,'2021-03-10','2021-02-08','2021-02-23','325k/unit on multi ; 3.2MM on retail',FALSE,TRUE,''),
('Pine Crest','6 - Passed','Charleston-North Charleston, SC',464,1945,102370,47500000,'2021-03-04','2021-02-01','2021-02-16','upper 40M range ; can go separate',FALSE,TRUE,''),
('Meriwether Place Apartments','6 - Passed','Raleigh-Durham-Chapel Hill, NC',256,1996,155000,39680000,'2021-03-04','2021-02-01','2021-02-16','mid 150k''s/unit ; can go separate',FALSE,TRUE,''),
('Wildgrass Luxury Apartments','6 - Passed','Tampa-St. Petersburg-Clearwater, FL',321,2020,NULL,NULL,'2021-02-24','2021-02-01','2021-02-16','emailed for pricing 2/1/21 ; followed up on pricing 2/16/21',FALSE,TRUE,''),
('Sandtown Vista Apartments','6 - Passed','Atlanta, GA',350,2009,165000,57750000,'2021-02-11','2021-01-12','2021-02-16','160-170/unit',TRUE,TRUE,''),
('Discovery on Broad','6 - Passed','Raleigh-Durham-Chapel Hill, NC',320,2001,192500,61600000,'2021-02-16','2021-01-11','2021-02-16','low to mid $190k/unit ; low 4% cap range',TRUE,TRUE,''),
('River Pointe Apartments','6 - Passed','Tampa-St. Petersburg-Clearwater, FL',212,1973,NULL,NULL,'2021-02-16','2021-02-11','2021-02-16','emailed for pricing 2/11/21',FALSE,TRUE,''),
('The Wilder','6 - Passed','Charleston-North Charleston, SC',286,2020,NULL,NULL,NULL,'2021-02-12','2021-02-16','',TRUE,TRUE,''),
('Crowne at Old Carolina','6 - Passed','',199,2010,NULL,NULL,NULL,'2021-02-12','2021-02-16','',TRUE,TRUE,''),
('Caroline Luxury Apartments','6 - Passed','Charleston-North Charleston, SC',237,2018,316455,75000000,'2021-03-16','2021-02-11','2021-02-16','4.7 blended cap rate (low to mid 70Ms)',FALSE,TRUE,''),
('The Lory of Braden River','6 - Passed','Sarasota-Bradenton, FL',270,2002,NULL,NULL,'2021-02-24','2021-02-11','2021-02-16','emailed for pricing 2/16/21',FALSE,TRUE,''),
('The Grove Apartments','6 - Passed','Orlando, FL',216,1973,129629,28000000,NULL,'2021-02-11','2021-02-16','24MM with loan assumption and 28MM free and clear ; early/mid March',FALSE,TRUE,''),
('Atlas Germantown','6 - Passed','Nashville, TN',101,2018,311881,31500000,'2021-02-18','2021-01-14','2021-02-16','31.5M ; 4% cap with adjusted Y1 taxes',FALSE,TRUE,''),
('Spalding Bridge','6 - Passed','Atlanta, GA',192,1984,187500,36000000,'2021-03-04','2020-07-30','2021-02-16','$36MM ; no new materials yet not on market yet ; Maybe opportunity to pre-empt ; Part of Radco portfolio offered last fall, will come back on the market after original buyer flaked out',TRUE,TRUE,''),
('Mallory Square','6 - Passed','Washington, DC-MD-VA',365,2015,287671,105000000,'2021-02-18','2021-01-12','2021-02-11','105MM / 290k/doorish; mid 4 cap',FALSE,TRUE,''),
('The Sheridan North Druid Hills','6 - Passed','Atlanta, GA',329,2008,240000,78960000,'2021-02-04','2021-01-04','2021-02-08','emailed for pricing 1/4/21 ; followed up 1/22/21',TRUE,TRUE,''),
('ARCOS','6 - Passed','Sarasota-Bradenton, FL',228,2019,333333,76000000,'2021-02-03','2021-01-15','2021-02-08','waiting for access to war room',TRUE,TRUE,'')
ON CONFLICT (name) DO NOTHING;

INSERT INTO deals (name,status,market,units,year_built,price_per_unit,purchase_price,bid_due_date,added,modified,comments,flagged,hot,broker) VALUES
('The Vale at the Parks','6 - Passed','Washington, DC-MD-VA',301,2021,423588,127500000,NULL,'2021-02-08','2021-02-08','$145-130M low 5s cap; waiting for access to war room',FALSE,TRUE,''),
('Palm Breeze at Keys Gate','6 - Passed','Miami, FL',157,2007,190000,29830000,'2021-02-11','2021-01-15','2021-02-01','townhomes (157 out of the 245 unit community) ; 190k/unit ; 5.25 cap',FALSE,TRUE,''),
('View At Legacy Oaks Apartments','6 - Passed','Raleigh-Durham-Chapel Hill, NC',304,2009,205592,62500000,'2021-01-27','2020-12-21','2021-01-28','low $60m ; +$200k PU ; CFO 1/25+',TRUE,TRUE,''),
('The Historic Hyde Park Collection','6 - Passed','Tampa-St. Petersburg-Clearwater, FL',65,1925,200000,13000000,'2021-02-17','2021-01-12','2021-01-27','195k-200k / unit ; waiting for access to war room',FALSE,TRUE,''),
('Whisper Valley - GFO Home','6 - Passed','Austin-San Marcos, TX',100,NULL,NULL,NULL,'2021-01-28','2021-01-11','2021-01-27','Single Family Dev Opportunity ; Number of parcels to be bought TBD',FALSE,TRUE,''),
('Bell West End Apartments','6 - Passed','Raleigh-Durham-Chapel Hill, NC',340,2014,227941,77500000,'2020-10-08','2020-09-09','2021-01-27','$77-$78M range ; this was also on the market in October ''20',TRUE,TRUE,''),
('Sevona Westover Hills','6 - Passed','San Antonio, TX',296,2012,NULL,NULL,NULL,'2020-10-07','2021-01-27','off-market; steel castle capital 4-pack
uw w/o actuals',FALSE,TRUE,''),
('Sevona Park Row','6 - Passed','Houston, TX',390,2004,NULL,NULL,NULL,'2020-10-07','2021-01-27','off-market; steel castle capital 4-pack
uw w/o actuals',FALSE,TRUE,''),
('San Marino','6 - Passed','Houston, TX',241,2016,NULL,NULL,NULL,'2020-09-14','2021-01-27','',TRUE,TRUE,''),
('The Highbank Luxury Apartments','6 - Passed','Houston, TX',284,2017,193661,55000000,NULL,'2020-09-14','2021-01-27','',TRUE,FALSE,''),
('The Brazos Apartments','6 - Passed','Dallas-Fort Worth, TX',286,1998,178321,51000000,NULL,'2020-10-16','2021-01-27','off-market; Angelo Gordon wants out
Hilltop is sponsor',TRUE,TRUE,''),
('Sevona Avion','6 - Passed','Fort Worth, TX',329,2012,NULL,NULL,NULL,'2020-10-07','2021-01-27','off-market; steel castle capital 4-pack
uw without actuals',FALSE,TRUE,''),
('The Courts of Bent Tree','6 - Passed','Dallas-Fort Worth, TX',168,1990,NULL,NULL,NULL,'2020-09-29','2021-01-27','off-market / uw w/o actuals
unsolicited offer to get attention of seller',FALSE,TRUE,''),
('Valencia Apartments','6 - Passed','Dallas-Fort Worth, TX',167,1995,167664,28000000,NULL,'2020-09-04','2021-01-27','Paskin Group is seller, had big prepayment on debt',TRUE,FALSE,''),
('Locust 210 Lofts','6 - Passed','Dallas-Fort Worth, TX',54,NULL,NULL,NULL,NULL,'2019-02-25','2021-01-27','',TRUE,TRUE,''),
('Sevona Tranquility Lake','6 - Passed','Brazoria, TX',212,2002,NULL,NULL,NULL,'2020-10-07','2021-01-27','off-market; steel castle capital 4-pack
uw w/o actuals',FALSE,TRUE,''),
('Mag & May','6 - Passed','Fort Worth, TX',240,2019,NULL,NULL,'2021-02-16','2020-09-25','2021-01-26','',TRUE,FALSE,''),
('Bridges at Chapel Hill','6 - Passed','Raleigh-Durham-Chapel Hill, NC',144,1990,160000,23040000,'2021-02-04','2021-01-12','2021-01-25','160k/unit',FALSE,TRUE,''),
('Marquis Midtown West','6 - Passed','Atlanta, GA',156,1997,NULL,NULL,NULL,'2021-01-14','2021-01-22','Need financials',FALSE,TRUE,''),
('Montgomery Club Apartments','6 - Passed','Washington, DC-MD-VA',269,1987,NULL,NULL,NULL,'2021-01-11','2021-01-15','',TRUE,TRUE,''),
('Gables Columbus Center','6 - Passed','Miami, FL',200,2018,515000,103000000,'2021-02-09','2021-01-11','2021-01-15','$101-105M range ; low 4% cap on yr 1 proforma',FALSE,TRUE,''),
('Winters Creek Apartments','6 - Passed','Atlanta, GA',200,NULL,NULL,NULL,NULL,'2021-01-08','2021-01-15','',TRUE,FALSE,''),
('The Heights at Old Peachtree','6 - Passed','Atlanta, GA',298,2020,NULL,NULL,NULL,'2021-01-13','2021-01-15','coming out in late Jan ;',FALSE,TRUE,''),
('Crest at Riverside','6 - Passed','Atlanta, GA',396,1995,169191,67000000,NULL,'2020-11-16','2021-01-15','169k/unit ; OM coming soon',FALSE,TRUE,''),
('Gables Upper Rock','6 - Passed','Washington, DC-MD-VA',551,2012,267695,147500000,'2021-01-28','2020-12-14','2021-01-15','North of $145M',FALSE,TRUE,''),
('Somerhill Farms','6 - Passed','Washington, DC-MD-VA',140,2006,307142,43000000,'2020-12-10','2020-11-09','2021-01-15','$43M',TRUE,FALSE,''),
('Stonegrove Fall Creek','6 - Passed','Houston, TX',322,2019,NULL,NULL,NULL,'2020-11-17','2021-01-12','',TRUE,TRUE,''),
('Newbergh ATL Apartments','6 - Passed','Atlanta, GA',258,2019,NULL,NULL,NULL,'2020-11-12','2021-01-11','emailed for pricing 11/12/20 ; Kees is going to call the broker',FALSE,TRUE,''),
('Mosaic at Largo Station Apartments','6 - Passed','Washington, DC-MD-VA',242,2008,258264,62500000,'2020-10-22','2020-09-30','2021-01-07','low 60Ms - Will touring 10/13

closing Jan 2021 at $64 MM',TRUE,FALSE,''),
('Preston View','6 - Passed','Raleigh-Durham-Chapel Hill, NC',382,2000,201047,76800000,'2020-10-19','2020-10-05','2021-01-07','off mkt to limited buyer pool

located on Prestonwood CC golf course w lots of views, great demos, VA upside - most units are original

perfect for Torchlight...

CLOSED Jan 2021 for $78.5 MM to BentallGreenOak (205k / unit)',TRUE,TRUE,''),
('The Hills at East Cobb','6 - Passed','Atlanta, GA',266,1972,140000,37240000,'2020-10-22','2020-08-18','2021-01-04','high 140s/unit ; used to be on the market now the buyers are looking for LP equity',FALSE,TRUE,''),
('Dutch Village Apartments','6 - Passed','Baltimore, MD',544,1967,NULL,NULL,NULL,'2021-01-04','2021-01-04','already under contract',FALSE,TRUE,''),
('Pleasant View Apartments','6 - Passed','Baltimore, MD',259,1972,NULL,NULL,NULL,'2021-01-04','2021-01-04','already under contract',FALSE,TRUE,''),
('Laurel Pines Apartments','6 - Passed','Washington, DC-MD-VA',235,1961,NULL,NULL,NULL,'2021-01-04','2021-01-04','does will know the price? ; 4.6% fixed loan must be assumed ($23,946,000)',FALSE,TRUE,''),
('Rock Springs Duplexes','6 - Passed','Austin-San Marcos, TX',152,1997,213815,32500000,'2020-12-08','2020-11-09','2020-12-16','',TRUE,TRUE,''),
('Sunrise Briar Forest','6 - Passed','Houston, TX',240,2014,NULL,NULL,NULL,'2020-10-20','2020-12-16','',TRUE,TRUE,''),
('Vickers Roswell','6 - Passed','Atlanta, GA',79,2018,NULL,NULL,'2021-01-07','2020-11-09','2020-12-15','emailed for pricing 11/9/20',FALSE,TRUE,''),
('Edge And Stone','6 - Passed','San Antonio, TX',335,2020,170149,57000000,'2020-12-08','2020-10-20','2020-12-10','Carbon Thompson development',TRUE,TRUE,''),
('The Carolyn','6 - Passed','Dallas-Fort Worth, TX',319,2020,227272,72500000,'2020-12-08','2020-11-16','2020-12-10','',TRUE,TRUE,''),
('Sterling Magnolia Apartments','6 - Passed','Charlotte-Gastonia-Rock Hill, NC-SC',174,2004,235000,40890000,'2020-10-26','2020-09-28','2020-12-08','230-240 / door',FALSE,TRUE,''),
('Stoney Ridge','6 - Passed','Washington, DC-MD-VA',262,1985,209923,55000000,NULL,'2020-08-11','2020-12-08','accepting offers on rolling basis; still on mkt as of 10/12. Jay to tour area 10/13. - JS',TRUE,FALSE,''),
('The Brittany','6 - Passed','Washington, DC-MD-VA',73,1963,226027,16500000,'2020-11-11','2020-10-01','2020-12-08','',TRUE,FALSE,''),
('ARIUM Pinnacle Ridge','6 - Passed','Raleigh-Durham-Chapel Hill, NC',350,1988,171428,60000000,'2020-11-12','2020-03-13','2020-12-08','will hit market soon (10/12) pre-mkt pricing not attractive enough to make offer - wait and see how marketing process goes. -JS...marketing started 10/13/20',TRUE,FALSE,''),
('Port RVA Apartments','6 - Passed','Richmond-Petersburg, VA',103,2015,184650,19019000,NULL,'2020-11-02','2020-12-08','includes adjacent parcel where 188 units can be constructed',FALSE,TRUE,''),
('Berkshire 54 Apartment Homes','6 - Passed','Raleigh-Durham-Chapel Hill, NC',296,1976,122500,36260000,NULL,'2020-11-09','2020-12-08','low 120''s per door',FALSE,TRUE,''),
('eLofts','6 - Passed','Washington, DC-MD-VA',200,2017,NULL,NULL,NULL,'2020-11-15','2020-12-08','27.7MM LP Equity Investment (Equity Recapitalization)',FALSE,TRUE,''),
('Latitude 28','6 - Passed','Orlando, FL',354,1974,149717,53000000,'2020-12-11','2020-11-09','2020-12-08','53M',FALSE,TRUE,''),
('The Life at Clifton Glen Apartments','6 - Passed','Atlanta, GA',556,1972,NULL,NULL,'2020-12-09','2020-11-15','2020-12-08','emailed for pricing 11/15/20',FALSE,TRUE,''),
('Retreat at Riverside Apartments','6 - Passed','Atlanta, GA',412,1999,NULL,NULL,'2020-12-21','2020-11-23','2020-12-08','emailed for pricing 11/23/20',FALSE,TRUE,''),
('The Oxford','6 - Passed','Washington, DC-MD-VA',187,2018,171122,32000000,'2020-12-08','2020-11-15','2020-12-08','32M...low 5% cap on actual...mid 5%s cap year 1',TRUE,TRUE,''),
('Forest Cove','6 - Passed','Atlanta, GA',638,1985,NULL,NULL,'2020-12-17','2020-11-16','2020-12-08','emailed for pricing 11/16/20 ; part of portfolio with Crest at Riverside',FALSE,TRUE,''),
('The Park At Sorrento Apartment Homes','6 - Passed','Greenville-Spartanburg-Anderson, SC',246,1987,NULL,NULL,NULL,'2020-11-09','2020-12-07','portfolio with Park at Toscana ; preemptive offer accepted (taken)',FALSE,TRUE,''),
('The Park at Toscana Apartment Homes','6 - Passed','Greenville-Spartanburg-Anderson, SC',172,1972,NULL,NULL,NULL,'2020-11-09','2020-12-07','preemptive offer accepted (taken) ; portfolio with Park at Sorrento',FALSE,TRUE,''),
('Brook Arbor','6 - Passed','Raleigh-Durham-Chapel Hill, NC',302,1997,NULL,NULL,'2020-11-24','2020-11-18','2020-12-07','',TRUE,FALSE,''),
('Solana Vista','6 - Passed','Sarasota-Bradenton, FL',200,1984,155000,31000000,'2020-11-17','2020-11-02','2020-12-07','$31M',FALSE,TRUE,''),
('Timberlake Village Apartments','6 - Passed','Nashville, TN',252,1986,NULL,NULL,'2020-11-17','2020-11-02','2020-12-07','emailed for pricing 11/2/20',FALSE,TRUE,''),
('The Tuscany Apartments','6 - Passed','Washington, DC-MD-VA',104,2007,341346,35500000,'2020-11-19','2020-10-19','2020-12-07','35-36M
near landmark mall (broadstone van dorn)',FALSE,TRUE,''),
('Preserve at Mountain Island Lake','6 - Passed','Charlotte-Gastonia-Rock Hill, NC-SC',240,2019,180000,43200000,'2020-11-12','2020-10-14','2020-12-07','High $170s / Low $180s / unit
NW CLT, just outside of beltway off hwy 16 - looks like good access but dont know this area well',FALSE,TRUE,''),
('The Lakes at Windward Apartments','6 - Passed','Atlanta, GA',294,1987,200000,58800000,'2020-11-12','2020-10-12','2020-12-07','$200k/unit',TRUE,FALSE,''),
('Century Summerfield At Morgan Metro','6 - Passed','Washington, DC-MD-VA',478,2008,NULL,NULL,'2020-12-01','2020-10-19','2020-12-07','waiting for access to war room; emailed for pricing 10/19/20',FALSE,TRUE,''),
('Southern Piedmont Portfolio','6 - Passed','Raleigh-Durham-Chapel Hill, NC',2322,1982,NULL,NULL,'2020-12-03','2020-11-09','2020-12-07','emailed for pricing 11/9/20 ; 8 assets (1 Durham, 2 Charlotte)',FALSE,TRUE,''),
('Fox Hill Apartments','6 - Passed','Austin-San Marcos, TX',288,2010,211805,61000000,'2020-12-01','2020-10-28','2020-12-03','',TRUE,TRUE,''),
('The James on South First','6 - Passed','Austin-San Marcos, TX',250,2016,200000,50000000,NULL,'2020-10-27','2020-12-03','',TRUE,TRUE,''),
('Marquette at Piney Point','6 - Passed','Houston, TX',318,2004,138364,44000000,'2020-11-18','2020-11-02','2020-11-16','Marquette bought from Camden at $44mm in 2013; loan coming due in March 2021
Harvey impact was 32 units - remodeled and achieving $125-150 premiums
TCR developed',TRUE,TRUE,''),
('The Arbors of Las Colinas Apartments','6 - Passed','Dallas-Fort Worth, TX',408,1984,147058,60000000,NULL,'2020-09-14','2020-11-16','',TRUE,TRUE,''),
('Spring Parc','6 - Passed','Dallas-Fort Worth, TX',304,1986,141447,43000000,'2020-10-29','2020-09-14','2020-11-16','9-foot ceilings',TRUE,TRUE,''),
('Jones & Rio Apartment Homes','6 - Passed','San Antonio, TX',191,2018,NULL,NULL,'2020-11-12','2020-10-01','2020-11-16','',TRUE,TRUE,''),
('Kelley @ Samuels Ave','6 - Passed','Fort Worth, TX',353,2019,NULL,NULL,'2020-11-12','2020-10-14','2020-11-16','',TRUE,TRUE,''),
('Avana Sterling Ridge Apartments','6 - Passed','Houston, TX',254,2005,188976,48000000,'2020-10-27','2020-10-06','2020-11-16','Underwrites very well',TRUE,TRUE,''),
('Mosaic at Mueller Luxury Apartments','6 - Passed','Austin-San Marcos, TX',433,2009,219399,95000000,'2020-11-18','2020-10-28','2020-11-16','has ground lease',TRUE,TRUE,''),
('Bella Palazzo','6 - Passed','Houston, TX',242,2018,NULL,NULL,NULL,'2020-10-28','2020-11-13','HUD loan assumption',TRUE,TRUE,''),
('Lenox Overlook Apartments','6 - Passed','San Antonio, TX',338,2019,173076,58500000,'2020-10-29','2020-10-01','2020-11-10','5 groups in B&F north of $58mm',TRUE,TRUE,''),
('Los Robles Apartments','6 - Passed','San Antonio, TX',306,2019,176470,54000000,'2020-09-17','2020-09-03','2020-11-10','~$50mm valuation as of 9/10/2020',TRUE,TRUE,''),
('The Crossings Apartments','6 - Passed','Atlanta, GA',380,1985,NULL,NULL,'2020-11-16','2020-09-21','2020-11-10','part of portfolio with The Knolls; emailed for pricing 9/21/20',FALSE,TRUE,''),
('The Knolls','6 - Passed','Atlanta, GA',312,1985,NULL,NULL,'2020-11-16','2020-09-21','2020-11-10','part of portfolio with The Crossings; emailed for pricing 9/21/20',FALSE,TRUE,''),
('The Riley','6 - Passed','Dallas-Fort Worth, TX',262,2018,NULL,NULL,'2020-10-29','2020-10-01','2020-11-04','',TRUE,TRUE,''),
('Century Galleria Lofts','6 - Passed','Houston, TX',223,2004,NULL,NULL,NULL,'2020-10-30','2020-10-30','',TRUE,TRUE,''),
('Collier Ridge Apartments','6 - Passed','Atlanta, GA',300,1981,NULL,NULL,NULL,'2020-10-22','2020-10-29','emailed for pricing 10/22/20
off 75, loan assumption',FALSE,TRUE,''),
('Smith & Porter','6 - Passed','Atlanta, GA',116,2019,215517,25000000,NULL,'2020-10-19','2020-10-29','25M
new construction, downtown',FALSE,TRUE,''),
('Cardinal House','6 - Passed','Washington, DC-MD-VA',14,2020,607142,8500000,NULL,'2020-10-19','2020-10-29','mid $8M range
luxury development in Columbia Heights',FALSE,TRUE,''),
('Waterford Place at Mt. Zion Apartments','6 - Passed','Atlanta, GA',400,1995,142500,57000000,'2020-10-29','2020-10-12','2020-10-29','$140-145/unit',FALSE,TRUE,''),
('Coral Pointe at The Forum','6 - Passed','Fort Myers-Cape Coral, FL',252,2017,212301,53500000,'2020-10-21','2020-10-19','2020-10-29','53.5M',FALSE,TRUE,''),
('Treviso Grand Apartments','6 - Passed','Sarasota-Bradenton, FL',272,2018,227500,61880000,'2020-10-27','2020-10-13','2020-10-29','225k-230k / unit',FALSE,TRUE,''),
('Pavilion Townplace','6 - Passed','Dallas-Fort Worth, TX',236,NULL,313559,74000000,'2020-10-20','2020-09-21','2020-10-28','$145k avg. income
looks like it will get preempted, speaking directly',TRUE,TRUE,''),
('Evans Ranch Apartments','6 - Passed','San Antonio, TX',329,2012,148936,49000000,'2020-10-20','2020-09-24','2020-10-28','need to tour',TRUE,TRUE,''),
('Cooper Glen','6 - Passed','Dallas-Fort Worth, TX',240,1998,NULL,NULL,'2020-10-22','2020-10-01','2020-10-28','',TRUE,TRUE,''),
('MELA Luxury Apartments','6 - Passed','San Antonio, TX',360,2020,NULL,NULL,'2020-10-29','2020-09-24','2020-10-28','',TRUE,FALSE,''),
('The Saint Mary','6 - Passed','Austin-San Marcos, TX',240,2019,NULL,NULL,'2020-10-28','2020-09-25','2020-10-28','',TRUE,FALSE,''),
('Wheelhouse of Fair Oaks','6 - Passed','Washington, DC-MD-VA',491,2015,269857,132500000,'2020-11-10','2020-10-01','2020-10-28','emailed for pricing 10/1/20',FALSE,TRUE,''),
('Village 1373','6 - Passed','Greensboro--Winston-Salem--High Point, NC',332,1987,87500,29050000,'2020-11-05','2020-10-01','2020-10-28','mid to high $80s/unit',FALSE,TRUE,''),
('Westchester at the Pavilions Apartments','6 - Passed','Washington, DC-MD-VA',500,2009,265000,132500000,'2020-11-05','2020-10-12','2020-10-28','low $130Ms',FALSE,TRUE,''),
('CB Lofts','6 - Passed','Atlanta, GA',164,2005,170731,28000000,'2020-10-30','2020-08-25','2020-10-22','at or above $28M',FALSE,TRUE,''),
('The Lofts at West 7th','6 - Passed','Fort Worth, TX',537,2011,NULL,NULL,'2020-10-20','2020-10-20','2020-10-21','',TRUE,TRUE,''),
('Rockbrook Village Apartments','6 - Passed','Dallas-Fort Worth, TX',440,1997,154545,68000000,'2020-10-29','2020-09-23','2020-10-21','Model is a DRAFT, need to tour
10/20 update:  preempted with Stewart Creek',TRUE,FALSE,''),
('Stewart Creek Apartments','6 - Passed','Dallas-Fort Worth, TX',414,1999,166666,69000000,'2020-10-29','2020-09-23','2020-10-21','Model is a DRAFT, need to tour
10/20 update:  preempted',TRUE,FALSE,''),
('Trellis Apartments','6 - Passed','Atlanta, GA',210,1986,147500,30975000,'2020-11-05','2020-09-22','2020-10-21','mid-high 140s/unit',FALSE,TRUE,''),
('Tapestry at Brentwood Town Center Apartments','6 - Passed','Nashville, TN',393,2015,330788,130000000,'2020-11-06','2020-10-12','2020-10-20','Also has retail; high-$120M to low-$130M',FALSE,TRUE,''),
('Cortland Spring Plaza','6 - Passed','Houston, TX',340,NULL,152941,52000000,'2020-10-15','2020-09-11','2020-10-20','Taxes need to uw at 100% of price',TRUE,TRUE,''),
('Bell Hill Country Apartments','6 - Passed','Austin-San Marcos, TX',276,2009,192028,53000000,'2020-10-14','2020-09-24','2020-10-20','core+ return profile',TRUE,TRUE,''),
('Somerset Apartments','6 - Passed','Dallas-Fort Worth, TX',372,1986,NULL,NULL,'2020-10-28','2020-10-12','2020-10-19','',TRUE,TRUE,'')
ON CONFLICT (name) DO NOTHING;

INSERT INTO deals (name,status,market,units,year_built,price_per_unit,purchase_price,bid_due_date,added,modified,comments,flagged,hot,broker) VALUES
('Bell Columbia Apartments','6 - Passed','Baltimore, MD',184,1986,NULL,NULL,'2020-10-29','2020-09-21','2020-10-16','followed up on timing and pricing 10/1/20',FALSE,TRUE,''),
('Palms at Clear Lake','6 - Passed','Houston, TX',240,1999,137500,33000000,NULL,'2020-09-14','2020-10-14','Underwrites well',TRUE,FALSE,''),
('Lotus Village Apartment Homes','6 - Passed','Austin-San Marcos, TX',222,2012,NULL,NULL,'2020-10-14','2020-09-29','2020-10-14','loan assumption',TRUE,TRUE,''),
('Kia Ora Luxury Apartments','6 - Passed','Dallas-Fort Worth, TX',250,2007,228000,57000000,NULL,'2020-09-21','2020-10-14','Model is a Draft, need to tour',TRUE,FALSE,''),
('Hermosa Village Apartments','6 - Passed','Austin-San Marcos, TX',238,2019,NULL,NULL,'2020-10-14','2020-09-25','2020-10-14','need to uw',TRUE,TRUE,''),
('Pecos Flats','6 - Passed','San Antonio, TX',384,2014,143229,55000000,'2020-10-07','2020-09-11','2020-10-14','Underwrites pretty well at ~$51,000,000',TRUE,FALSE,''),
('Enclave at Mary''s Creek Apartments','6 - Passed','Brazoria, TX',240,1999,170833,41000000,'2020-10-06','2020-09-14','2020-10-14','',TRUE,TRUE,''),
('Trinity at Left Bank','6 - Passed','Fort Worth, TX',337,2019,249258,84000000,'2020-10-13','2020-09-11','2020-10-12','~ $79,000,000 valuation at 4.5% year one cap',TRUE,TRUE,''),
('Tribeca at Camp Springs','6 - Passed','Washington, DC-MD-VA',222,2008,301801,67000000,'2020-10-19','2020-09-02','2020-10-12','followed up on timing 10/1/20',FALSE,TRUE,''),
('Andover Place at Cross Creek Apartments','6 - Passed','Tampa-St. Petersburg-Clearwater, FL',336,1997,178571,60000000,'2020-10-09','2020-10-05','2020-10-12','must go as portfolio for $120M; part of portfolio with Addison Park at Cross Creek',FALSE,TRUE,''),
('Addison Park at Cross Creek Apartments','6 - Passed','Tampa-St. Petersburg-Clearwater, FL',336,1999,178571,60000000,'2020-10-09','2020-10-05','2020-10-12','must go as portfolio for $120M; part of portfolio with Andover Place at Cross Creek',FALSE,TRUE,''),
('Admiral Place Apartments','6 - Passed','Washington, DC-MD-VA',410,1966,186585,76500000,'2020-11-11','2020-10-12','2020-10-12','$76 to $77 M',FALSE,TRUE,''),
('The Jamison','6 - Passed','Orlando, FL',315,2020,NULL,NULL,NULL,'2020-10-12','2020-10-12','emailed for pricing  10/12/20',FALSE,TRUE,''),
('ECCO On Orange Apartments','6 - Passed','Orlando, FL',300,2019,NULL,NULL,NULL,'2020-10-12','2020-10-12','emailed for pricing 10/12/20',FALSE,TRUE,''),
('Woodbridge Apartment Homes','6 - Passed','Charlotte-Gastonia-Rock Hill, NC-SC',184,1982,103260,19000000,NULL,'2020-10-05','2020-10-12','The current loan is a Freddie Mac through North Marg at 3.8% with an outstanding balance of $7,360,244.30 that matures June 2026; 18.5-19.5M; Here is the status on Woodbridge.  It is originally 192 1 and 2 bedroom units.  One 16 unit building burned down that included 12 1 Bedrooms and 12 2 Bedrooms.  We decided to replace the 1 building and the double tennis court with 2 buildings.  Those buildings will add 36 units to the property with addition of 12 new 2 Bedrooms and 24 3 Bedrooms for a total of 212 units.  We believe the new 2 Bedrooms could lease for in excess of $1295 and the 3 Bedrooms in excess of $1595.  The zoning is now approved which will bring the property able to have to move the max density of 269 in case anything else ever happens.',FALSE,TRUE,''),
('The Reserve at Waterford Lakes Apartments','6 - Passed','Charlotte-Gastonia-Rock Hill, NC-SC',140,1998,155000,21700000,'2020-10-09','2020-10-05','2020-10-12','150s/unit; submitted CA 10/5/20 (waiting for T12 and RR)... we need to give feedback by 10/9/20',FALSE,FALSE,''),
('Canopy at Ginter Park','6 - Passed','Richmond-Petersburg, VA',301,2020,265780,80000000,'2020-10-22','2020-09-09','2020-10-08','$80mm; no CFO date per 10/1/20',FALSE,TRUE,''),
('Acadia by Cortland','6 - Passed','Washington, DC-MD-VA',630,2000,289682,182500000,'2020-10-15','2020-09-10','2020-10-08','182.5MM',FALSE,TRUE,''),
('Trinity Commons at Erwin','6 - Passed','Raleigh-Durham-Chapel Hill, NC',342,2012,270000,92340000,'2020-10-21','2020-09-21','2020-10-08','270k/unit',FALSE,TRUE,''),
('Hangar Apartments','6 - Passed','Dallas-Fort Worth, TX',268,1980,NULL,NULL,NULL,'2020-10-07','2020-10-07','',TRUE,TRUE,''),
('The Annex Apartments','6 - Passed','Dallas-Fort Worth, TX',267,1985,NULL,NULL,NULL,'2020-10-07','2020-10-07','',TRUE,TRUE,''),
('Forty200 Apartments','6 - Passed','Dallas-Fort Worth, TX',512,1983,NULL,NULL,NULL,'2020-10-07','2020-10-07','',TRUE,TRUE,''),
('Current At The Grid Apartments','6 - Passed','Fort Worth, TX',192,1978,NULL,NULL,NULL,'2020-10-07','2020-10-07','',TRUE,TRUE,''),
('The Hudson','6 - Passed','Fort Worth, TX',660,1984,NULL,NULL,NULL,'2020-10-07','2020-10-07','',TRUE,TRUE,''),
('The Residence on Lamar Apartments','6 - Passed','Fort Worth, TX',482,1976,NULL,NULL,NULL,'2020-10-07','2020-10-07','',TRUE,TRUE,''),
('AMP At The Grid Apartments','6 - Passed','Fort Worth, TX',446,1970,NULL,NULL,NULL,'2020-10-07','2020-10-07','',TRUE,TRUE,''),
('Landings at Brooks City Base','6 - Passed','San Antonio, TX',300,2012,173333,52000000,'2020-10-13','2020-09-11','2020-10-06','100% real estate tax exemption forever, loan assumption (full term IO)
Starts to make sense at $49,000,000',TRUE,FALSE,''),
('The Union At River East','6 - Passed','Fort Worth, TX',190,2019,171052,32500000,'2020-10-06','2020-09-10','2020-10-06','~ $26,000,000 valuation as of 9/9/2020',TRUE,TRUE,''),
('Trinity Urban Apartments - Bluff & District','6 - Passed','Fort Worth, TX',256,2014,174218,44600000,'2020-10-06','2020-10-06','2020-10-06','',TRUE,TRUE,''),
('Trinity Bluff Apartments','6 - Passed','Fort Worth, TX',304,2007,182565,55500000,'2020-10-06','2020-10-06','2020-10-06','',TRUE,TRUE,''),
('Solmar on Sixth Luxury Apartments','6 - Passed','Fort Lauderdale-Hollywood, FL',286,2009,332167,95000000,'2020-10-20','2020-10-01','2020-10-06','mid 90Ms',FALSE,TRUE,''),
('Broadstone 8 One Hundred','6 - Passed','Austin-San Marcos, TX',376,2015,NULL,NULL,NULL,'2020-09-17','2020-10-05','',TRUE,FALSE,''),
('Cameron Court','6 - Passed','Washington, DC-MD-VA',460,1997,391304,180000000,'2020-10-13','2020-09-10','2020-10-05','180Mish',FALSE,TRUE,''),
('Centro Arlington','6 - Passed','Washington, DC-MD-VA',366,2019,546448,200000000,'2020-10-20','2020-09-03','2020-10-05','also has retail; $200M ($160M resi; $40M retail); CFO still TBD per 10/1/20',FALSE,TRUE,''),
('Isles of Gateway Apartments','6 - Passed','Tampa-St. Petersburg-Clearwater, FL',212,1987,155660,33000000,NULL,'2020-07-29','2020-10-05','can submit offer anytime; 33M with loan assumption; followed up to see if still on market 10/1/20',FALSE,TRUE,''),
('Vista at Palma Sola','6 - Passed','Sarasota-Bradenton, FL',340,1991,161764,55000000,NULL,'2020-07-17','2020-10-05','',FALSE,TRUE,''),
('Hamilton Ridge Apartment Homes','6 - Passed','Raleigh-Durham-Chapel Hill, NC',178,1986,NULL,NULL,NULL,'2020-09-22','2020-10-05','',FALSE,TRUE,''),
('Mariners Crossing Apartment Homes','6 - Passed','Raleigh-Durham-Chapel Hill, NC',306,1996,NULL,NULL,NULL,'2020-09-22','2020-10-05','',FALSE,TRUE,''),
('Newport Colony Apartments','6 - Passed','Orlando, FL',476,1990,178571,85000000,'2020-10-14','2020-09-09','2020-10-05','$85MM+',FALSE,TRUE,''),
('Lofts at South Lake','6 - Passed','Orlando, FL',144,2019,218750,31500000,NULL,'2020-08-18','2020-10-05','$31.5M; followed up to see if still on market 10/1/20',FALSE,TRUE,''),
('ARIUM Grandewood','6 - Passed','Orlando, FL',306,2005,NULL,NULL,'2020-10-14','2020-09-21','2020-10-05','emailed for pricing 9/21/20; followed up on pricing 10/1/20',FALSE,TRUE,''),
('The Lexington at Winter Park','6 - Passed','Orlando, FL',228,1971,207236,47250000,'2020-10-09','2020-09-02','2020-10-05','',FALSE,TRUE,''),
('Lago Paradiso at the Hammocks','6 - Passed','Miami, FL',424,1987,219339,93000000,'2020-10-07','2020-08-24','2020-10-05','Pricing here is $93MM.  Loan assumption with existing debt of $54mm (first and second).  Blended interest rate is 4.38% with a few years of IO left. Cap rate just under 5%.',FALSE,TRUE,''),
('The Landings at Pembroke Lakes Apartments','6 - Passed','Fort Lauderdale-Hollywood, FL',358,1989,223463,80000000,'2020-10-08','2020-09-08','2020-10-05','~$80,000,000',FALSE,TRUE,''),
('Cedar Flats','6 - Passed','Charlotte-Gastonia-Rock Hill, NC-SC',82,2016,232500,19065000,'2020-10-08','2020-09-21','2020-10-05','low $230s/unit',FALSE,TRUE,''),
('Alta Warp + Weft','6 - Passed','Charlotte-Gastonia-Rock Hill, NC-SC',261,2019,257500,67207500,'2020-10-14','2020-09-22','2020-10-05','upper $250s/unit',FALSE,TRUE,''),
('Novel Perimeter by Crescent Communities','6 - Passed','Atlanta, GA',320,2018,296875,95000000,'2020-10-08','2020-09-21','2020-10-05','mid $90M range',FALSE,TRUE,''),
('Arborview at Riverside and Liriope Apartments','6 - Passed','Baltimore, MD',372,1992,201612,75000000,'2020-10-14','2020-09-09','2020-10-05','$75MMish',FALSE,TRUE,''),
('The Hamptons at Palm Beach Gardens','6 - Passed','West Palm Beach-Boca Raton, FL',224,2013,379464,85000000,'2020-10-15','2020-09-14','2020-10-05','80Ms',FALSE,TRUE,''),
('West Village','6 - Passed','Raleigh-Durham-Chapel Hill, NC',608,2015,NULL,NULL,'2020-10-17','2020-09-28','2020-10-05','',FALSE,TRUE,''),
('The Douglas at Constant Friendship Apartments','6 - Passed','Baltimore, MD',136,1990,NULL,NULL,'2020-10-14','2020-10-05','2020-10-05','emailed for pricing 10/5/20',FALSE,TRUE,''),
('Sanibel Straits','6 - Passed','Fort Myers-Cape Coral, FL',224,2019,NULL,NULL,'2020-10-15','2020-09-28','2020-10-05','',FALSE,TRUE,''),
('Astoria at Celebration','6 - Passed','Orlando, FL',306,2015,NULL,NULL,NULL,'2020-10-01','2020-10-05','',FALSE,TRUE,''),
('Eagle''s Point Apartments','6 - Passed','Fort Worth, TX',240,1986,NULL,NULL,NULL,'2020-09-14','2020-10-02','',TRUE,TRUE,''),
('Belmont Place Apartments','6 - Passed','Atlanta, GA',326,2005,283742,92500000,'2020-10-01','2020-09-09','2020-10-02','low $90Ms',FALSE,TRUE,''),
('Notting Hill Luxury Apartments','6 - Passed','Atlanta, GA',709,2000,253878,180000000,'2020-10-01','2020-09-09','2020-10-02','$180M',FALSE,TRUE,''),
('The Park at Steele Creek','6 - Passed','Charlotte-Gastonia-Rock Hill, NC-SC',264,1997,180000,47520000,'2020-10-01','2020-09-09','2020-10-02','$180k/door',FALSE,TRUE,''),
('Harbortown Apartments','6 - Passed','Orlando, FL',428,1999,226635,97000000,'2020-10-01','2020-09-09','2020-10-02','$97M',FALSE,TRUE,''),
('Broadstone on Fifth','6 - Passed','Fort Worth, TX',345,2019,NULL,NULL,NULL,'2020-10-01','2020-10-01','',TRUE,TRUE,''),
('The Cottages at Ridge Point','6 - Passed','Athens, GA',216,2019,250000,54000000,'2020-10-06','2020-09-03','2020-10-01','$250/unit',TRUE,TRUE,''),
('Azalea Hill Apartment Homes','6 - Passed','Greenville-Spartanburg-Anderson, SC',160,1998,143750,23000000,NULL,'2020-08-25','2020-10-01','',TRUE,TRUE,''),
('Marbella Place Apartment Homes','6 - Passed','Atlanta, GA',368,1999,NULL,NULL,'2020-09-30','2020-08-18','2020-10-01','emailed for pricing 8/18/20',FALSE,TRUE,''),
('Stillwater at Grandview Cove','6 - Passed','Greenville-Spartanburg-Anderson, SC',240,1989,130000,31200000,NULL,'2020-08-10','2020-10-01','"neighboring property closing at $130k/unit"; no longer available per 10/1/20',FALSE,TRUE,''),
('Worthington Luxury Apartments','6 - Passed','Charlotte-Gastonia-Rock Hill, NC-SC',284,2006,NULL,NULL,NULL,'2020-09-01','2020-10-01','emailed for pricing 9/1/20; nothing in war room yet',FALSE,TRUE,''),
('Atkins Circle','6 - Passed','Charlotte-Gastonia-Rock Hill, NC-SC',568,2004,NULL,NULL,NULL,'2020-09-01','2020-10-01','emailed for pricing 9/1/20; part of "All-American Portfolio"; nothing in war room yet',FALSE,TRUE,''),
('Bell Ballantyne Apartments','6 - Passed','Charlotte-Gastonia-Rock Hill, NC-SC',210,2009,312500,65625000,'2020-10-08','2020-09-21','2020-09-29','310-315/unit',TRUE,TRUE,''),
('Harbor Pointe','6 - Passed','Charleston-North Charleston, SC',344,1987,188953,65000000,'2020-10-05','2020-09-21','2020-09-29','low to mid $60M range',FALSE,TRUE,''),
('The Preserve at Spring Lake','6 - Passed','Orlando, FL',320,1972,195000,62400000,NULL,'2020-09-08','2020-09-29','no war room yet; mid $190k+/unit',FALSE,TRUE,''),
('Bayside Arbors Apartments','6 - Passed','Tampa-St. Petersburg-Clearwater, FL',436,1994,NULL,NULL,NULL,'2020-08-05','2020-09-29','emailed for pricing 8/5/20; coming soon no war room yet',FALSE,TRUE,''),
('The Trestles Apartments','6 - Passed','Raleigh-Durham-Chapel Hill, NC',280,1986,NULL,NULL,NULL,'2020-07-28','2020-09-29','',TRUE,TRUE,''),
('Ardmore Heritage','6 - Passed','Raleigh-Durham-Chapel Hill, NC',260,2014,173076,45000000,NULL,'2020-09-15','2020-09-29','$44-$46M range',TRUE,FALSE,''),
('Hudson Cary Weston Apartments','6 - Passed','Raleigh-Durham-Chapel Hill, NC',288,1997,201701,58090140,NULL,'2020-08-27','2020-09-29','***** taken under contract at ~ 200k / unit

loan quote $41,244,000 at 71% LTV so $58,090,140.8',TRUE,TRUE,''),
('Hidden Lakes','6 - Passed','Fort Worth, TX',312,1996,150641,47000000,NULL,'2020-09-04','2020-09-28','2 pack with Ranch at Fossil Creek, CAF is seller
Preemptive strike - awarded 9/25/2020',TRUE,TRUE,''),
('Ranch at Fossil Creek','6 - Passed','Fort Worth, TX',274,2002,160583,44000000,NULL,'2020-09-04','2020-09-28','2 pack with Hidden Lakes, CAF is seller
Preemptive strike  - awarded 9/25/2020',TRUE,TRUE,''),
('Addison Park','6 - Passed','Charlotte-Gastonia-Rock Hill, NC-SC',426,NULL,NULL,NULL,NULL,'2020-01-10','2020-09-28','',TRUE,TRUE,''),
('Wish Portfolio','6 - Passed','Washington, DC-MD-VA',122,NULL,737704,90000000,'2020-10-02','2020-09-01','2020-09-28','emailed for pricing 9/1/20',FALSE,TRUE,''),
('5 Mockingbird Apartments','6 - Passed','Dallas-Fort Worth, TX',449,1998,NULL,NULL,NULL,'2020-09-25','2020-09-25','',TRUE,TRUE,''),
('Galleria Village Apartments','6 - Passed','Charlotte-Gastonia-Rock Hill, NC-SC',210,2006,190476,40000000,'2020-09-25','2020-09-17','2020-09-25','',TRUE,FALSE,''),
('Alesio Urban Center','6 - Passed','Dallas-Fort Worth, TX',908,1993,NULL,NULL,NULL,'2020-09-25','2020-09-25','',FALSE,TRUE,''),
('Village at Rayzor Ranch','6 - Passed','Dallas-Fort Worth, TX',300,2019,NULL,NULL,NULL,'2020-09-25','2020-09-25','',TRUE,TRUE,''),
('McKinney Village','6 - Passed','Dallas-Fort Worth, TX',245,2017,NULL,NULL,NULL,'2020-09-25','2020-09-25','',TRUE,TRUE,''),
('Brickyard apartment and townhomes','6 - Passed','Dallas-Fort Worth, TX',636,2019,NULL,NULL,NULL,'2020-09-25','2020-09-25','',TRUE,FALSE,''),
('Lure Apartments','6 - Passed','Dallas-Fort Worth, TX',144,1998,173611,25000000,NULL,'2020-09-11','2020-09-25','Off-market; Swapnil is seller - has loan maturing
Paid $22-23mm and has $18mm loan balance
Valuation is ~ $19,000,000; Seller can''t get debt that sizes to current loan balance',FALSE,TRUE,''),
('Alta Strand','6 - Passed','Dallas-Fort Worth, TX',400,2017,187500,75000000,'2020-09-30','2020-09-21','2020-09-25','',TRUE,FALSE,''),
('The Watson Apartments','6 - Passed','Dallas-Fort Worth, TX',247,2017,NULL,NULL,NULL,'2020-09-23','2020-09-25','',TRUE,TRUE,''),
('Highland Park West Lemmon','6 - Passed','Dallas-Fort Worth, TX',372,2009,NULL,NULL,'2020-09-23','2020-09-14','2020-09-25','',TRUE,TRUE,''),
('The Huntington Apartments','6 - Passed','Dallas-Fort Worth, TX',320,2018,240625,77000000,'2020-10-08','2020-09-11','2020-09-25','ZRS manages; 
4.1% year one cap at whisper pricing
makes sense closer to $72mm',TRUE,TRUE,''),
('Stone Canyon','6 - Passed','Houston, TX',216,1998,129629,28000000,NULL,'2020-09-14','2020-09-25','u/c at $28,000,000; 4.5% cap at that price',TRUE,FALSE,''),
('Richmond Towne Homes Apartments','6 - Passed','Houston, TX',188,1994,151595,28500000,'2020-09-16','2020-09-11','2020-09-25','',TRUE,TRUE,''),
('The Fields Woodlake Square','6 - Passed','Houston, TX',256,2013,142578,36500000,NULL,'2020-09-14','2020-09-25','loan assumption
amortizing debt with negative cash flow',TRUE,TRUE,''),
('Domain Boulder Creek','6 - Passed','Houston, TX',324,2019,160493,52000000,NULL,'2020-09-14','2020-09-25','',TRUE,FALSE,''),
('The Commons at Hollyhock','6 - Passed','Houston, TX',624,2015,NULL,NULL,NULL,'2020-09-25','2020-09-25','',TRUE,FALSE,''),
('Avana Cypress Estates Apartments','6 - Passed','Houston, TX',336,2003,NULL,NULL,NULL,'2020-09-14','2020-09-25','',TRUE,FALSE,''),
('Villages at Turtle Rock Apartments','6 - Passed','Austin-San Marcos, TX',356,2010,161797,57600000,'2020-09-11','2020-09-03','2020-09-25','~ $52,000,000 valuation as of 9/10/2020; 4.25% year one cap',TRUE,FALSE,''),
('The Aspect by Cortland','6 - Passed','Austin-San Marcos, TX',308,2001,NULL,NULL,NULL,'2020-09-25','2020-09-25','',FALSE,TRUE,''),
('Quest Apartments','6 - Passed','Austin-San Marcos, TX',333,2020,NULL,NULL,NULL,'2020-09-25','2020-09-25','',TRUE,FALSE,''),
('Lone Oak Apartments','6 - Passed','Austin-San Marcos, TX',304,2014,184210,56000000,'2020-09-09','2020-09-10','2020-09-25','~ $53,000,000 valuation as of 9/9/2020',TRUE,TRUE,''),
('Lenox Ridge','6 - Passed','Austin-San Marcos, TX',350,2020,237142,83000000,'2020-09-24','2020-09-02','2020-09-25','~ $74,000,000 valuation as of 9/9/2020',TRUE,FALSE,''),
('Aura Riverside','6 - Passed','Austin-San Marcos, TX',368,2019,NULL,NULL,NULL,'2020-09-14','2020-09-24','',TRUE,TRUE,''),
('Urban Crest Apartments','6 - Passed','San Antonio, TX',232,2015,NULL,NULL,'2020-10-06','2020-09-24','2020-09-24','',TRUE,TRUE,'')
ON CONFLICT (name) DO NOTHING;

INSERT INTO deals (name,status,market,units,year_built,price_per_unit,purchase_price,bid_due_date,added,modified,comments,flagged,hot,broker) VALUES
('The Heritage Apartments','6 - Passed','San Antonio, TX',305,2005,NULL,NULL,NULL,'2020-09-24','2020-09-24','PASS - loan assumption',TRUE,TRUE,''),
('Echelon at Monterrey Village','6 - Passed','San Antonio, TX',240,2018,160416,38500000,NULL,'2020-09-03','2020-09-24','~ $36,000,000 valuation as of 9/11/2020',TRUE,TRUE,''),
('Boardwalk Research Luxury Apartments','6 - Passed','San Antonio, TX',295,2015,177966,52500000,'2020-09-29','2020-09-03','2020-09-24','~ $47,500,000 valuation as of 9/10/2020',TRUE,FALSE,''),
('Avenues at Creekside','6 - Passed','San Antonio, TX',395,2013,164556,65000000,'2020-08-12','2020-09-03','2020-09-24','4.2% cap',TRUE,TRUE,''),
('Amara','6 - Passed','San Antonio, TX',308,2019,NULL,NULL,NULL,'2020-09-03','2020-09-24','',TRUE,TRUE,''),
('Bellevue Mill Apartments','6 - Passed','Raleigh-Durham-Chapel Hill, NC',112,2019,165000,18480000,NULL,'2020-07-15','2020-09-24','high 150s - high 160s / unit',FALSE,TRUE,''),
('Westland Park Apartments','6 - Passed','Jacksonville, FL',405,1990,139506,56500000,'2020-09-24','2020-09-08','2020-09-23','mid $56M range',FALSE,TRUE,''),
('Newnan Crossing Apartments','6 - Passed','Atlanta, GA',192,2004,NULL,NULL,'2020-09-22','2020-09-01','2020-09-23','emailed for pricing 9/1/20',FALSE,TRUE,''),
('Somerset Club Apartments','6 - Passed','Atlanta, GA',192,2004,NULL,NULL,'2020-09-22','2020-09-01','2020-09-23','emailed for pricing 9/1/20',FALSE,TRUE,''),
('Novel Research Park by Crescent Communities','6 - Passed','Charlotte-Gastonia-Rock Hill, NC-SC',280,2019,237500,66500000,'2020-09-18','2020-08-18','2020-09-23','high 230s/unit',FALSE,TRUE,''),
('Steeplechase Apartments','6 - Passed','Greensboro--Winston-Salem--High Point, NC',420,1991,129761,54500000,'2020-09-17','2020-08-25','2020-09-23','part of a portfolio with Park Forest; low to mid 54M range',TRUE,TRUE,''),
('Park Forest Apartments','6 - Passed','Greensboro--Winston-Salem--High Point, NC',151,1986,112582,17000000,'2020-09-17','2020-08-25','2020-09-23','part of a portfolio with steeplechase; 16M',TRUE,TRUE,''),
('Windemere Apartments','6 - Passed','Raleigh-Durham-Chapel Hill, NC',168,1990,NULL,NULL,NULL,'2020-09-21','2020-09-21','got preempted above guidance',FALSE,TRUE,''),
('The Doreen','6 - Passed','Washington, DC-MD-VA',109,1952,298165,32500000,'2020-09-23','2020-08-18','2020-09-15','emailed for pricing 8/18/20; Part of portfolio with The Aspen Group; low 30Ms for portfolio',FALSE,TRUE,''),
('The Aspen Group','6 - Passed','Washington, DC-MD-VA',121,1950,268595,32500000,'2020-09-23','2020-08-18','2020-09-15','emailed for pricing 8/18/20; part of Portfolio with The Doreen; low 30M for portfolio',FALSE,TRUE,''),
('Maple Springs Apartments','6 - Passed','Richmond-Petersburg, VA',268,1986,128731,34500000,'2020-09-23','2020-03-18','2020-09-10','put on pause in March, thinking about rolling it back out per Charles a/o 6/8 but nothing yet. available at pre-COVID pricing of $34.5 right now',TRUE,TRUE,''),
('The Palmer','6 - Passed','Charlotte-Gastonia-Rock Hill, NC-SC',318,2018,199685,63500000,NULL,'2020-08-12','2020-09-10','~$63-64M; 8/20 - 8/21 ish CFO date',TRUE,TRUE,''),
('The Point at Silver Spring','6 - Passed','Washington, DC-MD-VA',891,1968,255331,227500000,'2020-09-21','2020-08-17','2020-09-08','$225-$230M',FALSE,TRUE,''),
('Oak Mill Apartments','6 - Passed','Washington, DC-MD-VA',400,1984,200000,80000000,NULL,'2020-08-12','2020-09-02','accepting offers on rolling basis; by next friday if possible',FALSE,TRUE,''),
('Union Ledger Market','6 - Passed','Washington, DC-MD-VA',134,2020,NULL,NULL,NULL,'2020-08-10','2020-09-02','emailed for pricing 8/10/20; waiting for access to war room',FALSE,TRUE,''),
('Westwind Farms Apartments','6 - Passed','Washington, DC-MD-VA',464,2006,285560,132500000,NULL,'2020-08-10','2020-09-02','low-mid 130Ms',FALSE,TRUE,''),
('2807 Connecticut Avenue, NW','6 - Passed','Washington, DC-MD-VA',38,1924,723684,27500000,NULL,'2020-07-20','2020-09-02','high $20M range; no OM yet',FALSE,TRUE,''),
('The Alexander at Ghent Apartment Homes','6 - Passed','Norfolk-Virginia Beach-Newport News, VA-NC',268,2006,201492,54000000,'2020-09-10','2020-08-25','2020-09-02','part of portfolio with River Forest and Belvedere; $54Mish',FALSE,TRUE,''),
('River Forest Apartments','6 - Passed','Richmond-Petersburg, VA',300,2005,186666,56000000,'2020-09-10','2020-08-25','2020-09-02','part of portfolio with Belvedere and The Alexander; $56Mish',FALSE,TRUE,''),
('The Belvedere Apartments','6 - Passed','Richmond-Petersburg, VA',296,2005,216216,64000000,'2020-09-10','2020-08-25','2020-09-02','part of portfolio with River Forest and The Alexander; $64Mish',FALSE,TRUE,''),
('Moncler Willow Lake','6 - Passed','Tampa-St. Petersburg-Clearwater, FL',144,1986,121527,17500000,'2020-09-16','2020-08-13','2020-09-02','17-18M range',FALSE,TRUE,''),
('The Reserve at Cary Park Apartments','6 - Passed','Raleigh-Durham-Chapel Hill, NC',240,2007,200000,48000000,'2020-09-10','2020-08-12','2020-09-02','high 190s / 200ish per door',TRUE,TRUE,''),
('Ivy Walk Apartments','6 - Passed','Richmond-Petersburg, VA',248,2001,118951,29500000,'2020-09-03','2020-07-29','2020-09-02','29-20M PP',FALSE,TRUE,''),
('Century Cross Creek','6 - Passed','Tampa-St. Petersburg-Clearwater, FL',297,2014,189898,56400000,'2020-09-03','2020-04-03','2020-09-02','56.4M or 190k/unit; back on market after being halted for covid; CFO date early September',TRUE,TRUE,''),
('Edison Apartments','6 - Passed','Fort Myers-Cape Coral, FL',327,2020,225000,73575000,'2020-09-03','2020-08-25','2020-09-02','$220s/unit',FALSE,TRUE,''),
('The Residence at SouthPark','6 - Passed','Charlotte-Gastonia-Rock Hill, NC-SC',150,2007,500000,75000000,'2020-09-03','2020-07-29','2020-09-02','low ot mid 70s with loan assumption; mid 70s without free and clear; late aug / early sept per 8/5/20',FALSE,TRUE,''),
('Westwind Farms Apartments','6 - Passed','Washington, DC-MD-VA',464,2006,285560,132500000,'2020-09-09','2020-08-21','2020-09-02','low 130Ms',TRUE,TRUE,''),
('Bridgewater','6 - Passed','Orlando, FL',344,1973,156976,54000000,'2020-09-09','2020-08-12','2020-09-02','$54M / $157k/unit; waiting for access to war room',FALSE,TRUE,''),
('The Apartments at Blakeney','6 - Passed','Charlotte-Gastonia-Rock Hill, NC-SC',295,2007,237288,70000000,'2020-09-09','2020-08-10','2020-09-02','70M; timing likely early September',TRUE,TRUE,''),
('Barrington Place Apartments','6 - Passed','Charlotte-Gastonia-Rock Hill, NC-SC',348,1999,175000,60900000,'2020-08-21','2020-07-30','2020-09-02','all cash mid 170s/unit; high 160s/unit with debt assumption; part of portfolio with Barrington Place (can go seperately); coming soon no war room yet; followed up on timing 8/5/20',TRUE,TRUE,''),
('Waterlynn Ridge Apartments','6 - Passed','',312,2008,173076,54000000,'2020-08-21','2020-07-30','2020-09-02','all cash high 170s/unit; with debt assumption 170k/unit; part of portfolio with Barrington Place (can go seperately); coming soon no war room yet; followed up on timing 8/5/20',TRUE,FALSE,''),
('Grand Pavilion','6 - Passed','Tampa-St. Petersburg-Clearwater, FL',264,1984,125000,33000000,'2020-08-20','2020-07-30','2020-09-02','125k/unit; waiting for access to war room',FALSE,TRUE,''),
('Alexan Optimist Park','6 - Passed','Charlotte-Gastonia-Rock Hill, NC-SC',238,2019,267500,63665000,'2020-08-20','2020-07-21','2020-09-02','mid/high 260s/unit',FALSE,TRUE,''),
('District South','6 - Passed','Charlotte-Gastonia-Rock Hill, NC-SC',397,2018,221662,88000000,'2020-08-19','2020-08-18','2020-09-02','88M+',FALSE,TRUE,''),
('Daniel Island Village Apartments','6 - Passed','Charleston-North Charleston, SC',283,2008,210000,59430000,NULL,'2020-08-18','2020-09-02','targeting 210k/unit',TRUE,TRUE,''),
('The Courts of Avalon Apartments','6 - Passed','Baltimore, MD',258,1999,279069,72000000,'2020-09-10','2020-08-10','2020-09-02','emailed for pricing 8/10/20',FALSE,TRUE,''),
('Radius Sandy Springs','6 - Passed','Atlanta, GA',532,1980,NULL,NULL,'2020-08-27','2020-08-19','2020-09-02','',TRUE,TRUE,''),
('The Atlantic Medlock Bridge','6 - Passed','Atlanta, GA',320,1985,155000,49600000,'2020-09-18','2020-08-05','2020-08-26','mid 150k/unit; followed up on timing 8/13/20',FALSE,TRUE,''),
('Parc At Dunwoody Apartments','6 - Passed','Atlanta, GA',312,1979,144000,44928000,'2020-08-13','2020-07-09','2020-08-25','',TRUE,TRUE,''),
('Wildwood Ridge','6 - Passed','Atlanta, GA',546,1974,NULL,NULL,'2020-08-26','2020-08-05','2020-08-25','emailed for pricing 8/5/20',FALSE,TRUE,''),
('Radius Sandy Springs','6 - Passed','Atlanta, GA',532,1986,185000,98420000,'2020-08-27','2020-07-30','2020-08-18','mid 180s/unit',TRUE,TRUE,''),
('Parc 1346 Apartments','6 - Passed','Chattanooga, TN-GA',316,1999,145000,45820000,'2020-09-02','2020-08-05','2020-08-17','mid 140s/unit; waiting for access to war room',FALSE,TRUE,''),
('Cortona South Tampa','6 - Passed','Tampa-St. Petersburg-Clearwater, FL',300,2019,251666,75500000,'2020-08-12','2020-07-30','2020-08-13','75-76mm',FALSE,TRUE,''),
('Sundance Station','6 - Passed','Richmond-Petersburg, VA',300,1980,133333,40000000,'2020-07-29','2020-07-17','2020-08-13','7/28

Initial offer made at $40.250 MM. Awaiting broker feedback on B&F procedure, etc',TRUE,FALSE,''),
('Century Highland Creek','6 - Passed','Charlotte-Gastonia-Rock Hill, NC-SC',338,2013,183431,62000000,'2020-07-24','2020-07-22','2020-08-13','',TRUE,FALSE,''),
('Tarpon Harbour','6 - Passed','',106,2016,400943,42500000,NULL,'2020-07-28','2020-08-13','$41-$44MM',FALSE,TRUE,''),
('Grove at Deane Hill','6 - Passed','Knoxville, TN',272,1998,150735,41000000,NULL,'2020-08-05','2020-08-13','between 40M and 42M',FALSE,TRUE,''),
('Cross Creek At Victory Station','6 - Passed','Nashville, TN',248,2006,NULL,NULL,NULL,'2020-08-10','2020-08-13','emailed for pricing 8/10/20; coming soon no war room yet',FALSE,TRUE,''),
('Cross Creek at Grapevine Ranch','6 - Passed','Fort Worth, TX',392,2001,200000,78400000,NULL,'2020-07-31','2020-08-13','200k/unit',FALSE,TRUE,''),
('Amazon Last Mile (Edgewood, MD)','6 - Passed','Baltimore, MD',1,2020,27500000,27500000,'2020-08-20','2020-07-30','2020-08-12','4.75-5 cap; 27-28M; $130 psf; waiting for access to war room',FALSE,TRUE,''),
('Sixes Ridge Apartments','6 - Passed','Atlanta, GA',340,2019,205882,70000000,'2020-07-29','2020-07-01','2020-08-12','',FALSE,TRUE,''),
('Novo Avondale','6 - Passed','Atlanta, GA',374,1972,160427,60000000,'2020-08-11','2020-07-15','2020-08-12','$58-$62M',FALSE,TRUE,''),
('Ardmore & 28th Buckhead','6 - Passed','Atlanta, GA',165,2017,284848,47000000,NULL,'2020-07-01','2020-08-11','followed up on timing 8/5/20',TRUE,TRUE,''),
('The Legacy @ 2000','6 - Passed','Raleigh-Durham-Chapel Hill, NC',223,1979,132500,29547500,'2020-08-19','2020-07-15','2020-08-11','130-135k/unit',FALSE,TRUE,''),
('Highpoint Club Apartments','6 - Passed','Orlando, FL',348,1994,185344,64500000,'2020-08-13','2020-07-10','2020-08-11','64-65M',TRUE,TRUE,''),
('Montevista at Windermere Apartments','6 - Passed','Orlando, FL',360,1989,180555,65000000,'2020-08-13','2020-07-15','2020-08-11','',TRUE,TRUE,''),
('The Glen Apartments','6 - Passed','Washington, DC-MD-VA',152,NULL,NULL,NULL,NULL,'2020-06-28','2020-08-05','',TRUE,FALSE,''),
('Henley Tampa Palms','6 - Passed','Tampa-St. Petersburg-Clearwater, FL',315,1997,206349,65000000,NULL,'2020-06-18','2020-07-28','',TRUE,TRUE,''),
('Hawthorne at Clairmont','6 - Passed','Atlanta, GA',269,2009,180000,48420000,'2020-07-22','2020-01-28','2020-07-22','relaunch after corona',TRUE,TRUE,''),
('Ansley at Princeton Lakes Apartments','6 - Passed','Atlanta, GA',306,2009,NULL,NULL,'2020-07-28','2020-06-25','2020-07-22','emailed for pricing 6/25/20',FALSE,TRUE,''),
('Radius Palms','6 - Passed','Tampa-St. Petersburg-Clearwater, FL',540,1990,148148,80000000,'2020-07-24','2020-07-15','2020-07-22','part of central florida value-add portfolio',FALSE,TRUE,''),
('City Park Clearwater','6 - Passed','Tampa-St. Petersburg-Clearwater, FL',228,1990,195175,44500000,'2020-07-24','2020-07-15','2020-07-22','part of central florida value-add portfolio',FALSE,TRUE,''),
('Ashford on the Lake','6 - Passed','Tampa-St. Petersburg-Clearwater, FL',292,1984,159246,46500000,'2020-07-24','2020-07-15','2020-07-22','part of central florida value-add portfolio',FALSE,TRUE,''),
('Lakeside at Winter Park','6 - Passed','Orlando, FL',288,1986,187500,54000000,'2020-07-24','2020-07-15','2020-07-22','part of central florida value-add portfolio',FALSE,TRUE,''),
('Haven Fort Belvoir','6 - Passed','Washington, DC-MD-VA',76,1963,190789,14500000,NULL,'2020-06-16','2020-07-21','Accepting offers on rolling basis; strong possibility for a discount on PP',TRUE,TRUE,''),
('Haven Woodbridge','6 - Passed','Washington, DC-MD-VA',138,1987,206521,28500000,NULL,'2020-06-16','2020-07-21','Accepting offers on rolling basis; strong possibility for a discount on PP',TRUE,TRUE,''),
('Haven Mt Vernon','6 - Passed','Washington, DC-MD-VA',216,1987,240740,52000000,NULL,'2020-06-15','2020-07-21','Accepting offers on rolling basis; strong possibility for a discount on PP',TRUE,TRUE,''),
('The Edge at Lake Lotus Apartments','6 - Passed','Orlando, FL',168,1987,157738,26500000,NULL,'2020-06-19','2020-07-09','26-27M',FALSE,TRUE,''),
('Reserve at Cavalier','6 - Passed','Greenville-Spartanburg-Anderson, SC',152,1978,92500,14060000,NULL,'2020-06-25','2020-07-09','No OM yet; low 90k''s / unit; ~5.25 cap',FALSE,TRUE,''),
('St. Johns Plantation Apartments','6 - Passed','Jacksonville, FL',400,1989,160000,64000000,'2020-07-16','2020-06-18','2020-07-09','',FALSE,TRUE,''),
('The Kensley Apartment Homes','6 - Passed','Jacksonville, FL',300,2004,162500,48750000,'2020-07-15','2020-06-18','2020-07-09','This is a relaunch after corona',FALSE,TRUE,''),
('Spyglass at Cedar Cove Apartments','6 - Passed','',152,1985,180921,27500000,NULL,'2020-06-08','2020-07-07','',TRUE,FALSE,''),
('Serotina Lakes Apartments','6 - Passed','Jacksonville, FL',263,1987,90304,23750000,'2020-07-14','2020-06-23','2020-07-07','90k/unit; high 23Ms',FALSE,TRUE,''),
('2500 Biscayne at Wynwood Edge','6 - Passed','Miami, FL',156,2018,391025,61000000,NULL,'2020-06-30','2020-07-01','2500 Biscayne at Wynwood Edge  is the perfect property in Edgewater. Minutes from Wynwood, Downtown, Brickell, and the brand-new Design District. This towering luxury community offers breathtaking Bay views and an exclusive resort lifestyle with sleek and spacious residences overlooking the waterfront, to unmatched amenities and five-star services at your fingertips

Low Vacancy was caused by a 3rd Party management previously renting units as a Airbnb. All units are now being converted to one year leases and they expect full stabilization within 90 days

Website
www.2500biscaynemiami.com

Location: 2500 Biscayne at Wynwood Edge 2500 Biscayne Blvd Miami, Florida 33137
Units:  156  units/19 stories
Year Built: 2018
Class: A+
Area Class: A+
Occupancy: 71%+
Debt: Delivered Free & Clear
NOI: $3.2MM (Projected)
Cap: 4.8%

The asking price is $67.5MM....We suggest you engage the seller at $61MM',TRUE,TRUE,''),
('The District at Windy Hill','6 - Passed','Atlanta, GA',284,2019,216549,61500000,NULL,'2020-06-30','2020-06-30','',TRUE,FALSE,''),
('Edgewater on Lake Lynn','6 - Passed','Raleigh-Durham-Chapel Hill, NC',344,1985,145348,50000000,'2020-06-17','2020-03-13','2020-06-26','true off mkt VA deal, good location in NW Raleigh, aggressive cap rate going in but solid upside opportunity. Seller asking $54 MM (firm), we valued at $50

Show to Torchlight / LEM??

***Update 6/12 - Seller willing to take $50 MM but needs to move quick. offer would need to be in by 6/17',TRUE,TRUE,''),
('The Point at City Line','6 - Passed','Philadelphia, PA-NJ',302,1983,231788,70000000,NULL,'2020-06-18','2020-06-26','',FALSE,TRUE,''),
('Element 41','6 - Passed','Atlanta, GA',494,1988,161943,80000000,NULL,'2020-06-18','2020-06-26','low 160s/unit; ~$80M',FALSE,TRUE,''),
('Solis Decatur','6 - Passed','Atlanta, GA',290,2018,300000,87000000,NULL,'2020-06-05','2020-06-25','Off market - large deal, probably too big',TRUE,FALSE,''),
('Windsor Forest','6 - Passed','Fort Lauderdale-Hollywood, FL',300,1974,NULL,NULL,NULL,'2019-09-18','2020-06-05','',TRUE,TRUE,''),
('Willis Apartments','6 - Passed','Atlanta, GA',197,2018,NULL,NULL,NULL,'2019-09-17','2020-06-05','',TRUE,TRUE,''),
('Sterling Collier Hills Apartments','6 - Passed','Atlanta, GA',120,NULL,NULL,NULL,NULL,'2019-09-13','2020-06-05','',TRUE,TRUE,''),
('The Arbors','6 - Passed','Atlanta, GA',140,1987,NULL,NULL,NULL,'2019-09-12','2020-06-05','',TRUE,TRUE,''),
('3833 Peachtree','6 - Passed','Atlanta, GA',228,NULL,NULL,NULL,NULL,'2019-08-26','2020-06-05','',TRUE,TRUE,''),
('Advenir at Monterrey','6 - Passed','Sarasota-Bradenton, FL',243,1987,NULL,NULL,NULL,'2019-09-30','2020-06-05','',TRUE,TRUE,''),
('Brooklawn Apartments','6 - Passed','Washington, DC-MD-VA',86,NULL,NULL,NULL,NULL,'2019-09-28','2020-06-05','',TRUE,TRUE,''),
('Parc at 1695','6 - Passed','Atlanta, GA',252,1987,NULL,NULL,NULL,'2019-09-26','2020-06-05','',TRUE,TRUE,''),
('The Park at Levanzo','6 - Passed','Jacksonville, FL',360,1974,NULL,NULL,NULL,'2019-09-25','2020-06-05','',TRUE,TRUE,''),
('The Tradition at Summerville Apartment Homes','6 - Passed','Charleston-North Charleston, SC',232,2004,NULL,NULL,NULL,'2019-09-25','2020-06-05','',TRUE,TRUE,''),
('Woodbridge Apartments','6 - Passed','Nashville, TN',220,1980,NULL,NULL,NULL,'2019-09-24','2020-06-05','',TRUE,TRUE,''),
('Shiloh Green Apartments','6 - Passed','Atlanta, GA',236,NULL,NULL,NULL,NULL,'2019-11-20','2020-06-05','',TRUE,TRUE,''),
('Central Gardens Grand','6 - Passed','West Palm Beach-Boca Raton, FL',124,NULL,NULL,NULL,NULL,'2019-11-15','2020-06-05','',TRUE,TRUE,''),
('Weston Lakeside','6 - Passed','Raleigh-Durham-Chapel Hill, NC',332,2006,NULL,NULL,NULL,'2019-11-13','2020-06-05','',TRUE,TRUE,''),
('Messenger Place Apartments','6 - Passed','Washington, DC-MD-VA',94,2018,NULL,NULL,NULL,'2019-10-29','2020-06-05','',TRUE,TRUE,''),
('Millspring Commons Apartments','6 - Passed','Richmond-Petersburg, VA',159,1972,NULL,NULL,NULL,'2019-09-30','2020-06-05','',TRUE,TRUE,'')
ON CONFLICT (name) DO NOTHING;

INSERT INTO deals (name,status,market,units,year_built,price_per_unit,purchase_price,bid_due_date,added,modified,comments,flagged,hot,broker) VALUES
('The Princeton At College Park','6 - Passed','Orlando, FL',205,NULL,NULL,NULL,NULL,'2019-08-22','2020-06-05','',TRUE,TRUE,''),
('@1377 Apartments','6 - Passed','Atlanta, GA',215,2014,NULL,NULL,NULL,'2019-12-06','2020-06-05','',TRUE,TRUE,''),
('Victoria Station Apartments','6 - Passed','Dallas-Fort Worth, TX',83,2011,NULL,NULL,NULL,'2019-06-20','2020-06-05','',TRUE,TRUE,''),
('Victoria Village','6 - Passed','Dallas-Fort Worth, TX',35,2007,NULL,NULL,NULL,'2019-06-20','2020-06-05','',TRUE,TRUE,''),
('Locust 210 Lofts','6 - Passed','Dallas-Fort Worth, TX',54,2013,NULL,NULL,NULL,'2019-06-20','2020-06-05','',TRUE,TRUE,''),
('The Adagio','6 - Passed','Dallas-Fort Worth, TX',67,2014,NULL,NULL,NULL,'2019-06-20','2020-06-05','',TRUE,TRUE,''),
('Viridian Design District','6 - Passed','Houston, TX',394,2015,NULL,NULL,NULL,'2018-06-21','2020-06-05','',TRUE,TRUE,''),
('Point at Perimeter','6 - Passed','Atlanta, GA',604,1991,NULL,NULL,NULL,'2018-06-21','2020-06-05','',TRUE,TRUE,''),
('Webb Bridge Crossing','6 - Passed','Atlanta, GA',164,1989,NULL,NULL,NULL,'2018-06-21','2020-06-05','',TRUE,TRUE,''),
('Avalon Woodland Park','6 - Passed','Washington, DC-MD-VA',392,2000,NULL,NULL,NULL,'2018-07-12','2020-06-05','',TRUE,TRUE,''),
('Horizons at Fossil Creek','6 - Passed','Fort Worth, TX',420,1998,NULL,NULL,NULL,'2018-07-24','2020-06-05','',TRUE,TRUE,''),
('Square One','6 - Passed','Atlanta, GA',203,2017,NULL,NULL,NULL,'2018-07-25','2020-06-05','',TRUE,TRUE,''),
('Avana Uptown','6 - Passed','Atlanta, GA',227,2006,NULL,NULL,NULL,'2018-08-06','2020-06-05','',TRUE,TRUE,''),
('Cornerstone','6 - Passed','Raleigh-Durham-Chapel Hill, NC',302,1997,NULL,NULL,NULL,'2018-08-06','2020-06-05','',TRUE,TRUE,''),
('Sandshell at Fossil Creek','6 - Passed','Fort Worth, TX',252,1986,NULL,NULL,NULL,'2018-08-06','2020-06-05','',TRUE,TRUE,''),
('The Village','6 - Passed','Raleigh-Durham-Chapel Hill, NC',300,1997,NULL,NULL,NULL,'2018-07-24','2020-06-05','',TRUE,TRUE,''),
('Wyatt at Presidio Junction','6 - Passed','Fort Worth, TX',348,2009,NULL,NULL,NULL,'2018-08-10','2020-06-05','',TRUE,TRUE,''),
('City West','6 - Passed','Orlando, FL',300,1990,NULL,NULL,NULL,'2018-08-23','2020-06-05','',TRUE,TRUE,''),
('The Emerson 1600','6 - Passed','Atlanta, GA',246,1985,NULL,NULL,NULL,'2018-09-04','2020-06-05','',TRUE,TRUE,''),
('Vinings Corner','6 - Passed','Atlanta, GA',360,1983,NULL,NULL,NULL,'2018-09-04','2020-06-05','',TRUE,TRUE,''),
('Southwinds Point','6 - Passed','Atlanta, GA',240,1993,NULL,NULL,NULL,'2018-09-04','2020-06-05','',TRUE,TRUE,''),
('Copper Mill','6 - Passed','Raleigh-Durham-Chapel Hill, NC',192,NULL,NULL,NULL,NULL,'2018-06-13','2020-06-05','',TRUE,TRUE,''),
('Point at Crabtree','6 - Passed','Raleigh-Durham-Chapel Hill, NC',336,1995,NULL,NULL,NULL,'2018-09-04','2020-06-05','',TRUE,TRUE,''),
('Fountains at Forrestwood','6 - Passed','Fort Myers-Cape Coral, FL',397,NULL,NULL,NULL,NULL,'2018-02-12','2020-06-05','',TRUE,TRUE,''),
('Vert at Six Forks','6 - Passed','Raleigh-Durham-Chapel Hill, NC',174,1986,NULL,NULL,NULL,'2018-09-28','2020-06-05','',TRUE,TRUE,''),
('Southern Oaks at Davis Park','6 - Passed','Raleigh-Durham-Chapel Hill, NC',287,2007,NULL,NULL,NULL,'2018-10-03','2020-06-05','',TRUE,TRUE,''),
('Enders Place at Baldwin Park Apartments','6 - Passed','Orlando, FL',220,NULL,NULL,NULL,NULL,'2020-01-10','2020-06-05','',TRUE,TRUE,''),
('Saxon Trace Apartments','6 - Passed','DaytonaBeach, FL',192,NULL,NULL,NULL,NULL,'2020-01-10','2020-06-05','',TRUE,TRUE,''),
('Waverly Place','6 - Passed','Charleston-North Charleston, SC',240,NULL,133333,32000000,NULL,'2020-01-22','2020-06-05','',TRUE,TRUE,''),
('Hawthorne at Clairmont','6 - Passed','Atlanta, GA',269,2009,NULL,NULL,NULL,'2020-01-27','2020-06-05','',FALSE,TRUE,''),
('The Plantation at Pleasant Ridge Apartments','6 - Passed','Greensboro--Winston-Salem--High Point, NC',288,2014,NULL,NULL,NULL,'2020-01-30','2020-06-05','',TRUE,TRUE,''),
('511 Queens','6 - Passed','Charlotte-Gastonia-Rock Hill, NC-SC',64,NULL,NULL,NULL,NULL,'2020-02-04','2020-06-05','',TRUE,TRUE,''),
('North Pointe Apartment Homes','6 - Passed','Washington, DC-MD-VA',235,1954,NULL,NULL,NULL,'2020-02-25','2020-06-05','',TRUE,TRUE,''),
('Lakeside Retreat at Peachtree Corners','6 - Passed','Atlanta, GA',328,1982,NULL,NULL,NULL,'2020-02-26','2020-06-05','',TRUE,TRUE,''),
('Riviera at Seaside Apartments','6 - Passed','Charleston-North Charleston, SC',252,NULL,NULL,NULL,NULL,'2020-02-28','2020-06-05','',FALSE,FALSE,''),
('Sheridan','6 - Passed','Washington, DC-MD-VA',56,NULL,NULL,NULL,NULL,'2020-03-11','2020-06-05','',TRUE,TRUE,''),
('Chase Heritage Apartment Homes','6 - Passed','Washington, DC-MD-VA',236,1986,NULL,NULL,NULL,'2020-03-16','2020-06-05','',TRUE,TRUE,''),
('River''s Edge at Manchester','6 - Passed','Richmond-Petersburg, VA',212,2018,NULL,NULL,NULL,'2020-04-09','2020-06-05','',TRUE,TRUE,''),
('2632 Tunlaw','6 - Passed','Washington, DC-MD-VA',21,1965,NULL,NULL,NULL,'2019-08-05','2020-06-05','',TRUE,TRUE,''),
('2634 Tunlaw','6 - Passed','Washington, DC-MD-VA',38,1965,NULL,NULL,NULL,'2019-08-05','2020-06-05','',TRUE,TRUE,''),
('Berkeley House','6 - Passed','Washington, DC-MD-VA',48,1964,NULL,NULL,NULL,'2019-08-05','2020-06-05','',TRUE,TRUE,''),
('Providence Lakes','6 - Passed','Tampa-St. Petersburg-Clearwater, FL',260,1996,NULL,NULL,NULL,'2018-10-02','2020-06-05','',TRUE,TRUE,''),
('Crowne at Swift Creek','6 - Passed','Richmond-Petersburg, VA',312,2004,NULL,NULL,NULL,'2018-09-25','2020-06-05','',TRUE,TRUE,''),
('Hawthorne at Clairmont','6 - Passed','Atlanta, GA',269,2009,NULL,NULL,NULL,'2018-10-12','2020-06-05','',TRUE,TRUE,''),
('Elevation 3505 - Phase 2','6 - Passed','Atlanta, GA',175,2007,NULL,NULL,NULL,'2018-09-24','2020-06-05','',TRUE,TRUE,''),
('Chroma Park','6 - Passed','Atlanta, GA',210,1999,NULL,NULL,NULL,'2018-10-16','2020-06-05','',TRUE,TRUE,''),
('McAlpine Ridge','6 - Passed','Charlotte-Gastonia-Rock Hill, NC-SC',320,1989,NULL,NULL,NULL,'2018-10-17','2020-06-05','',TRUE,TRUE,''),
('Walker Mill','6 - Passed','Washington, DC-MD-VA',366,NULL,NULL,NULL,NULL,'2018-10-23','2020-06-05','',TRUE,TRUE,''),
('Reserve at Ballenger Creek','6 - Passed','Washington, DC-MD-VA',204,2000,NULL,NULL,NULL,'2019-02-27','2020-06-05','',FALSE,TRUE,''),
('Wilton Tower','6 - Passed','Fort Lauderdale-Hollywood, FL',150,1971,NULL,NULL,NULL,'2019-02-27','2020-06-05','',TRUE,TRUE,''),
('Palette at Arts District','6 - Passed','Washington, DC-MD-VA',243,2012,NULL,NULL,NULL,'2019-06-17','2020-06-05','',TRUE,TRUE,''),
('Regatta at Lake Lynn','6 - Passed','Raleigh-Durham-Chapel Hill, NC',392,1987,NULL,NULL,NULL,'2019-07-18','2020-06-05','',TRUE,TRUE,''),
('Bell Wakefield Apartments','6 - Passed','Raleigh-Durham-Chapel Hill, NC',360,2000,NULL,NULL,NULL,'2019-07-18','2020-06-05','',TRUE,TRUE,''),
('The Columns at Akers Mill','6 - Passed','Atlanta, GA',400,1968,NULL,NULL,NULL,'2019-07-17','2020-06-05','',TRUE,TRUE,''),
('501 Towns','6 - Passed','Raleigh-Durham-Chapel Hill, NC',236,1971,NULL,NULL,NULL,'2019-07-17','2020-06-05','',TRUE,TRUE,''),
('Victoria Heights (1)','6 - Passed','Dallas-Fort Worth, TX',34,2007,NULL,NULL,NULL,'2019-06-24','2020-06-05','',TRUE,TRUE,''),
('Victoria Heights (2)','6 - Passed','Dallas-Fort Worth, TX',42,2009,NULL,NULL,NULL,'2019-06-20','2020-06-05','',TRUE,TRUE,''),
('Element 28','6 - Passed','Washington, DC-MD-VA',101,2017,NULL,NULL,NULL,'2019-08-14','2020-06-05','',TRUE,TRUE,''),
('The Reserve at Ridgewood','6 - Passed','Atlanta, GA',269,1981,NULL,NULL,NULL,'2019-08-07','2020-06-05','',TRUE,TRUE,''),
('ARIUM Bayou Point','6 - Passed','Tampa-St. Petersburg-Clearwater, FL',212,1987,NULL,NULL,NULL,'2019-08-07','2020-06-05','',TRUE,TRUE,''),
('The Riverside','6 - Passed','Washington, DC-MD-VA',23,1956,NULL,NULL,NULL,'2019-08-05','2020-06-05','',TRUE,TRUE,''),
('2628 Tunlaw','6 - Passed','Washington, DC-MD-VA',18,1965,NULL,NULL,NULL,'2019-08-05','2020-06-05','',TRUE,TRUE,''),
('2626 Tunlaw','6 - Passed','Washington, DC-MD-VA',17,1965,NULL,NULL,NULL,'2019-08-05','2020-06-05','',TRUE,TRUE,''),
('180 West Apartments','6 - Passed','Raleigh-Durham-Chapel Hill, NC',250,1987,NULL,NULL,NULL,'2019-08-01','2020-06-05','',TRUE,TRUE,''),
('Somerset','6 - Passed','Washington, DC-MD-VA',57,NULL,NULL,NULL,NULL,'2019-08-22','2020-06-05','',TRUE,TRUE,''),
('Runaway Bay Apartments','6 - Passed','Columbus, OH',192,1984,NULL,NULL,NULL,'2019-08-16','2020-06-05','',TRUE,TRUE,''),
('The Bradley','6 - Passed','Washington, DC-MD-VA',165,2015,NULL,NULL,NULL,'2019-08-14','2020-06-05','',TRUE,TRUE,''),
('Vineyard at Hammock Ridge','6 - Passed','Orlando, FL',280,2015,NULL,NULL,NULL,'2019-03-04','2020-06-05','',TRUE,TRUE,''),
('Flats at 55 Twelve','6 - Passed','Raleigh-Durham-Chapel Hill, NC',268,2001,NULL,NULL,NULL,'2019-03-04','2020-06-05','',TRUE,TRUE,''),
('Accent Waterworks','6 - Passed','Atlanta, GA',181,2016,NULL,NULL,NULL,'2019-02-28','2020-06-05','',TRUE,TRUE,''),
('Charlestowne','6 - Passed','Atlanta, GA',184,1999,NULL,NULL,NULL,'2019-02-28','2020-06-05','',TRUE,TRUE,''),
('Hamptons at East Cobb','6 - Passed','Atlanta, GA',196,1997,NULL,NULL,NULL,'2019-02-28','2020-06-05','',TRUE,TRUE,''),
('Capella','6 - Passed','Atlanta, GA',320,1984,NULL,NULL,NULL,'2019-02-21','2020-06-05','',TRUE,TRUE,''),
('Arbors of Dublin','6 - Passed','Columbus, OH',288,1988,NULL,NULL,NULL,'2019-01-22','2020-06-05','',TRUE,TRUE,''),
('The Glen at Lauderhill','6 - Passed','Fort Lauderdale-Hollywood, FL',405,1989,NULL,NULL,NULL,'2019-02-06','2020-06-05','',TRUE,TRUE,''),
('Laurel View','6 - Passed','Charlotte-Gastonia-Rock Hill, NC-SC',174,2018,NULL,NULL,NULL,'2019-02-11','2020-06-05','',TRUE,TRUE,''),
('Regal Vista','6 - Passed','Atlanta, GA',226,NULL,NULL,NULL,NULL,'2019-02-06','2020-06-05','',TRUE,TRUE,''),
('Bainbridge at Nona Place','6 - Passed','Orlando, FL',288,2018,NULL,NULL,NULL,'2019-01-08','2020-06-05','',TRUE,TRUE,''),
('Retreat at Market Square','6 - Passed','Washington, DC-MD-VA',206,2014,NULL,NULL,NULL,'2018-12-07','2020-06-05','',TRUE,TRUE,''),
('Avia St. Johns','6 - Passed','Jacksonville, FL',440,1989,NULL,NULL,NULL,'2019-01-07','2020-06-05','',TRUE,TRUE,''),
('Timothy Woods','6 - Passed','Athens, GA',204,1996,NULL,NULL,NULL,'2018-11-28','2020-06-05','',TRUE,TRUE,''),
('Earle Manor','6 - Passed','Washington, DC-MD-VA',140,1961,NULL,NULL,NULL,'2018-12-06','2020-06-05','',TRUE,TRUE,''),
('Sligo House & Corona Apartments','6 - Passed','Washington, DC-MD-VA',107,1960,NULL,NULL,NULL,'2018-12-06','2020-06-05','',TRUE,TRUE,''),
('Retreat at Market Square','6 - Passed','Washington, DC-MD-VA',206,NULL,NULL,NULL,NULL,'2018-11-26','2020-06-05','',TRUE,TRUE,''),
('Lenox at Patterson Place','6 - Passed','Raleigh-Durham-Chapel Hill, NC',292,NULL,NULL,NULL,NULL,'2018-10-17','2020-06-05','',TRUE,TRUE,''),
('Glen Lake','6 - Passed','Atlanta, GA',270,1982,NULL,NULL,NULL,'2018-10-01','2020-06-05','',TRUE,TRUE,''),
('Promenade Crossing','6 - Passed','Orlando, FL',212,1998,NULL,NULL,NULL,'2018-02-12','2020-06-05','',TRUE,TRUE,''),
('Sharon Crossing','6 - Passed','Charlotte-Gastonia-Rock Hill, NC-SC',144,1984,NULL,NULL,NULL,'2018-02-21','2020-06-05','',TRUE,TRUE,''),
('The Crossing at Quail Hollow','6 - Passed','Charlotte-Gastonia-Rock Hill, NC-SC',128,1985,NULL,NULL,NULL,'2018-02-22','2020-06-05','',TRUE,TRUE,''),
('Deco at CNB','6 - Passed','Richmond-Petersburg, VA',201,NULL,NULL,NULL,NULL,'2018-03-02','2020-06-05','',TRUE,TRUE,''),
('Rock Glen','6 - Passed','Baltimore, MD',242,1964,NULL,NULL,NULL,'2018-03-07','2020-06-05','',TRUE,TRUE,''),
('Autumn Ridge','6 - Passed','Atlanta, GA',113,1986,NULL,NULL,NULL,'2018-03-12','2020-06-05','',TRUE,TRUE,''),
('Wynfield Trace','6 - Passed','Atlanta, GA',146,1988,NULL,NULL,NULL,'2018-03-12','2020-06-05','',TRUE,TRUE,''),
('Ivy Ridge','6 - Passed','Atlanta, GA',207,NULL,NULL,NULL,NULL,'2018-03-15','2020-06-05','',TRUE,TRUE,''),
('The Shelby','6 - Passed','Washington, DC-MD-VA',24,1916,NULL,NULL,NULL,'2018-03-19','2020-06-05','',TRUE,TRUE,''),
('Jefferson Lakeside','6 - Passed','Atlanta, GA',323,1990,NULL,NULL,NULL,'2018-05-09','2020-06-05','',TRUE,TRUE,''),
('The Louis','6 - Passed','Washington, DC-MD-VA',268,2013,NULL,NULL,NULL,'2018-04-13','2020-06-05','',TRUE,TRUE,''),
('The Policy','6 - Passed','Washington, DC-MD-VA',62,1929,NULL,NULL,NULL,'2018-03-19','2020-06-05','',TRUE,TRUE,''),
('Matthews Reserve','6 - Passed','Charlotte-Gastonia-Rock Hill, NC-SC',212,1998,NULL,NULL,NULL,'2018-05-11','2020-06-05','',TRUE,TRUE,''),
('Avana Grogan''s Mill','6 - Passed','Houston, TX',384,NULL,NULL,NULL,NULL,'2018-05-14','2020-06-05','',TRUE,TRUE,'')
ON CONFLICT (name) DO NOTHING;

INSERT INTO deals (name,status,market,units,year_built,price_per_unit,purchase_price,bid_due_date,added,modified,comments,flagged,hot,broker) VALUES
('Avana Woodridge','6 - Passed','Houston, TX',216,NULL,NULL,NULL,NULL,'2018-05-14','2020-06-05','',TRUE,TRUE,''),
('Park Vue of Alexandria','6 - Passed','Washington, DC-MD-VA',196,1965,NULL,NULL,NULL,'2018-05-15','2020-06-05','',TRUE,TRUE,''),
('Madison Oaks','6 - Passed','Tampa-St. Petersburg-Clearwater, FL',250,1988,NULL,NULL,NULL,'2018-05-15','2020-06-05','',TRUE,TRUE,''),
('Avana Six Pines','6 - Passed','Houston, TX',360,NULL,NULL,NULL,NULL,'2018-05-14','2020-06-05','',TRUE,TRUE,''),
('Lorring Park','6 - Passed','Washington, DC-MD-VA',427,1967,NULL,NULL,NULL,'2018-05-15','2020-06-05','',TRUE,TRUE,''),
('Crestmont at Thornblade','6 - Passed','Greenville-Spartanburg-Anderson, SC',266,1998,NULL,NULL,NULL,'2018-06-14','2020-06-05','',TRUE,TRUE,''),
('The Avenue','6 - Passed','Tampa-St. Petersburg-Clearwater, FL',216,1984,NULL,NULL,NULL,'2018-06-18','2020-06-05','',TRUE,TRUE,''),
('17th St Lofts','6 - Passed','Atlanta, GA',147,NULL,NULL,NULL,NULL,'2018-06-20','2020-06-05','',TRUE,TRUE,''),
('The Clarion','6 - Passed','Atlanta, GA',217,1990,NULL,NULL,NULL,'2018-06-20','2020-06-05','',TRUE,TRUE,'')
ON CONFLICT (name) DO NOTHING;
