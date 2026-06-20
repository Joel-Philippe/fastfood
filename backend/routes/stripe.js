const express = require('express');
const router = express.Router();
const { body, validationResult } = require('express-validator');
const stripe = require('stripe')(process.env.STRIPE_SECRET_KEY);
const Order = require('../models/Order');
const { broadcastToAdmins, sendUpdateToTrackingToken } = require('../websocket');

router.post(
  '/create-payment-intent',
  [body('amount', 'Amount is required and must be an integer').isInt({ gt: 0 }), body('currency', 'Currency is required').not().isEmpty()],
  async (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ errors: errors.array() });
    }

    const { amount, currency } = req.body;

    try {
      const paymentIntent = await stripe.paymentIntents.create({
        amount,
        currency,
        automatic_payment_methods: {
          enabled: true,
        },
      });

      res.json({ clientSecret: paymentIntent.client_secret });
    } catch (error) {
      console.error('Error creating payment intent:', error);
      res.status(500).json({ error: error.message });
    }
  }
);

// --- Create Checkout Session for Web ---
router.post(
  '/create-checkout-session',
  async (req, res) => {
    try {
      const { amount, currency, success_url, cancel_url, items_summary, metadata, customer_email, customer_name, address } = req.body;

      const session = await stripe.checkout.sessions.create({
        payment_method_types: ['card'],
        customer_email: customer_email,
        line_items: [
          {
            price_data: {
              currency: currency || 'eur',
              product_data: {
                name: 'Commande Fast Food',
                description: items_summary || 'Votre sélection de délicieux plats',
              },
              unit_amount: amount,
            },
            quantity: 1,
          },
        ],
        mode: 'payment',
        success_url: success_url,
        cancel_url: cancel_url,
        metadata: metadata || {},
        billing_address_collection: 'required',
        shipping_address_collection: {
          allowed_countries: ['FR'],
        },
      });

      res.json({ url: session.url, id: session.id });
    } catch (error) {
      console.error('Error creating checkout session:', error);
      res.status(500).json({ error: error.message });
    }
  }
);

router.post('/webhook', async (req, res) => {
  const signature = req.headers['stripe-signature'];
  const webhookSecret = process.env.STRIPE_WEBHOOK_SECRET;

  if (!webhookSecret) {
    return res.status(500).send('Stripe webhook secret is not configured');
  }

  let event;
  try {
    event = stripe.webhooks.constructEvent(req.body, signature, webhookSecret);
  } catch (error) {
    console.error('Stripe webhook signature verification failed:', error.message);
    return res.status(400).send(`Webhook Error: ${error.message}`);
  }

  try {
    if (event.type === 'checkout.session.completed') {
      const session = event.data.object;
      const orderId = session.metadata?.orderId;

      if (orderId) {
        const updatedOrder = await Order.findByIdAndUpdate(
          orderId,
          {
            paymentStatus: 'paid',
            stripeSessionId: session.id,
            paidAt: new Date(),
          },
          { new: true }
        );

        if (updatedOrder) {
          const payload = {
            type: 'NEW_ORDER',
            order: updatedOrder.toObject(),
          };
          broadcastToAdmins(payload);

          if (updatedOrder.trackingToken) {
            sendUpdateToTrackingToken(updatedOrder.trackingToken, {
              type: 'PUBLIC_ORDER_STATUS_UPDATE',
              order: updatedOrder.toObject(),
            });
          }
        }
      }
    }

    res.json({ received: true });
  } catch (error) {
    console.error('Stripe webhook handling failed:', error);
    res.status(500).send('Webhook handler failed');
  }
});

module.exports = router;
