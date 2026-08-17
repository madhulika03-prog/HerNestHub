const Razorpay = require('razorpay');
const { createClient } = require('@supabase/supabase-js');

const VISIT_FEE = 200;
const DEPOSIT = 5000;
const DAILY_RATE = 800;
const DAILY_DEPOSIT = 3500;

module.exports = async function handler(req, res) {
  if (req.method !== 'POST') return res.status(405).json({ error: 'Method not allowed' });

  try {
    const supabase = createClient(process.env.SUPABASE_URL, process.env.SUPABASE_SERVICE_ROLE_KEY);
    const razorpay = new Razorpay({
      key_id: process.env.RAZORPAY_KEY_ID,
      key_secret: process.env.RAZORPAY_KEY_SECRET
    });

    const { purpose, roomType, stayType, days } = req.body;
    let amount;

    if (purpose === 'visit_fee') {
      amount = VISIT_FEE;
    } else if (purpose === 'booking') {
      if (!roomType) return res.status(400).json({ error: 'Missing roomType' });

      if (stayType === 'daily') {
        const numDays = Number(days);
        if (!numDays || numDays < 1) return res.status(400).json({ error: 'Invalid number of days' });
        amount = DAILY_DEPOSIT + (numDays * DAILY_RATE);
      } else {
        const { data: pkg, error } = await supabase
          .from('packages')
          .select('price')
          .eq('name', roomType)
          .limit(1)
          .maybeSingle();
        if (error || !pkg) return res.status(400).json({ error: 'Unknown room type' });
        amount = DEPOSIT + Number(pkg.price);
      }
    } else {
      return res.status(400).json({ error: 'Invalid purpose' });
    }

    const order = await razorpay.orders.create({
      amount: Math.round(amount * 100),
      currency: 'INR',
      receipt: `${purpose}_${Date.now()}`
    });

    res.status(200).json({ orderId: order.id, amount: order.amount, keyId: process.env.RAZORPAY_KEY_ID });
  } catch (err) {
    console.error('create-order error', err);
    res.status(500).json({ error: 'Failed to create order' });
  }
};
