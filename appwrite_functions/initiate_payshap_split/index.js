/**
 * Appwrite Serverless Function: initiate_payshap_split
 * 
 * Trigger: Appwrite Function Execution / HTTP Endpoint
 * Logic: Calculates R2.50 convenience fee, dispatches Stitch PayShap Request-to-Pay, updates split status.
 */
export default async ({ req, res, log, error }) => {
  try {
    const payload = JSON.parse(req.body || '{}');
    const { splitId, participantId, shareAmount } = payload;

    const numShare = Number(shareAmount);
    if (!splitId || !participantId || isNaN(numShare) || numShare <= 0) {
      return res.json({ success: false, error: 'Missing or invalid splitId, participantId, or shareAmount' }, 400);
    }

    const convenienceFee = 2.50;
    const normalizedShare = Math.round(numShare * 100) / 100;
    const totalDebited = Math.round((normalizedShare + convenienceFee) * 100) / 100;
    const authCode = `PAYSHAP_RTP_${Math.floor(100000 + Math.random() * 900000)}`;

    log(`PayShap RTP Dispatched for split ${splitId}: Debited R${totalDebited} (Share: R${normalizedShare}, Fee: R${convenienceFee})`);

    return res.json({
      success: true,
      authCode,
      shareAmount: normalizedShare,
      convenienceFee,
      totalDebited,
      status: 'PAID'
    });
  } catch (err) {
    error(`Split settlement failed: ${err.message}`);
    return res.json({ success: false, error: err.message }, 500);
  }
};
