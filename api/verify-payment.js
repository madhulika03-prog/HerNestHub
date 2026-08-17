const crypto = require('crypto');
const { createClient } = require('@supabase/supabase-js');

const supabase = createClient(process.env.SUPABASE_URL, process.env.SUPABASE_SERVICE_ROLE_KEY);

module.exports = async function handler(req, res) {
  if (req.method !== 'POST') return res.status(405).json({ error: 'Method not allowed' });

  try {
    const {
      razorpay_order_id,
      razorpay_payment_id,
      razorpay_signature,
      purpose,
      amount,
      visit,
      booking,
      idDocumentPath
    } = req.body;

    const expectedSignature = crypto
      .createHmac('sha256', process.env.RAZORPAY_KEY_SECRET)
      .update(`${razorpay_order_id}|${razorpay_payment_id}`)
      .digest('hex');

    if (expectedSignature !== razorpay_signature) {
      return res.status(400).json({ error: 'Invalid payment signature' });
    }

    if (purpose === 'visit_fee') {
      const { data: visitRow, error: visitErr } = await supabase
        .from('pg_visit_requests')
        .insert([{
          customer_name: visit.name,
          email: visit.email,
          phone: visit.phone,
          visit_datetime: visit.visit_datetime,
          message: visit.message
        }])
        .select('id')
        .single();
      if (visitErr) throw visitErr;

      const { error: payErr } = await supabase.from('payments').insert([{
        purpose: 'visit_fee',
        visit_request_id: visitRow.id,
        razorpay_order_id,
        razorpay_payment_id,
        amount,
        status: 'paid'
      }]);
      if (payErr) throw payErr;

      return res.status(200).json({ success: true });
    }

    if (purpose === 'booking') {
      const customerId = crypto.randomUUID();
      const { error: custErr } = await supabase.from('customers').insert([{
        id: customerId,
        name: booking.name,
        email: booking.email,
        phone: booking.phone
      }]);
      if (custErr) throw custErr;

      const { data: bookingRow, error: bookingErr } = await supabase
        .from('bookings')
        .insert([{
          customer_id: customerId,
          room_id: booking.room_id,
          package_id: booking.package_id,
          move_in_date: booking.move_in_date,
          notes: booking.notes,
          id_document_path: idDocumentPath,
          terms_accepted: true
        }])
        .select('id')
        .single();
      if (bookingErr) throw bookingErr;

      const { error: payErr } = await supabase.from('payments').insert([{
        purpose: 'booking',
        booking_id: bookingRow.id,
        razorpay_order_id,
        razorpay_payment_id,
        amount,
        status: 'paid'
      }]);
      if (payErr) throw payErr;

      return res.status(200).json({ success: true });
    }

    return res.status(400).json({ error: 'Unknown purpose' });
  } catch (err) {
    console.error('verify-payment error', err);
    return res.status(500).json({ error: 'Payment verification failed' });
  }
};
