import { HttpContext } from '@adonisjs/core/http'
import StaffProductFeedback from '#models/tenant/staff_product_feedback'
import Product from '#models/tenant/product'
import User from '#models/tenant/user'

function mapFeedback(f: StaffProductFeedback) {
  return {
    id: f.id,
    product_id: f.productId,
    productId: f.productId,
    product_name: f.productName,
    productName: f.productName,
    current_stock: f.currentStock,
    currentStock: f.currentStock,
    staff_user_id: f.staffUserId,
    staffUserId: f.staffUserId,
    staff_username: f.staffUsername || 'Staff',
    staffUsername: f.staffUsername || 'Staff',
    branch_id: f.branchId,
    branchId: f.branchId,
    urgency: f.urgency || 'normal',
    suggested_quantity: f.suggestedQuantity,
    suggestedQuantity: f.suggestedQuantity,
    notes: f.notes || '',
    status: f.status || 'pending',
    created_at: f.createdAt ? f.createdAt.toISO() : new Date().toISOString(),
    createdAt: f.createdAt ? f.createdAt.toISO() : new Date().toISOString(),
    updated_at: f.updatedAt ? f.updatedAt.toISO() : new Date().toISOString(),
    updatedAt: f.updatedAt ? f.updatedAt.toISO() : new Date().toISOString(),
  }
}

export default class StaffFeedbackController {
  async index({ request, response }: HttpContext) {
    const { status, urgency } = request.qs()
    const query = StaffProductFeedback.query().orderBy('id', 'desc')

    if (status && status !== 'all') {
      query.where('status', status)
    }
    if (urgency && urgency !== 'all') {
      query.where('urgency', urgency)
    }

    const feedbacks = await query.limit(100)
    return response.ok(feedbacks.map(mapFeedback))
  }

  async store({ request, response, authUser }: HttpContext) {
    const body = request.all()
    const pId = body.product_id ?? body.productId ?? null
    let pName = (body.product_name ?? body.productName ?? '').trim()
    let stock = Number(body.current_stock ?? body.currentStock ?? 0)

    if (pId) {
      const prod = await Product.query().where('id', pId).first()
      if (prod) {
        if (!pName) pName = prod.name
        stock = prod.stockQuantity
      }
    }

    if (!pName) {
      pName = 'Unspecified Drug'
    }

    const userId = body.staff_user_id ?? body.staffUserId ?? authUser?.id ?? null
    let userName = (body.staff_username ?? body.staffUsername ?? '').trim()
    if (!userName && userId) {
      const u = await User.query().where('id', userId).first()
      if (u) userName = u.username
    }
    if (!userName) userName = authUser?.username || 'Staff'

    const feedback = await StaffProductFeedback.create({
      productId: pId,
      productName: pName,
      currentStock: stock,
      staffUserId: userId,
      staffUsername: userName,
      branchId: Number(body.branch_id ?? body.branchId ?? 1),
      urgency: body.urgency || 'normal',
      suggestedQuantity: Math.max(1, Number(body.suggested_quantity ?? body.suggestedQuantity ?? 10)),
      notes: body.notes || null,
      status: 'pending',
    })

    return response.status(201).json(mapFeedback(feedback))
  }

  async update({ params, request, response }: HttpContext) {
    const feedback = await StaffProductFeedback.query().where('id', params.id).first()
    if (!feedback) {
      return response.status(404).json({ error: 'Staff feedback not found.' })
    }

    const { status } = request.all()
    if (status) {
      feedback.status = status
      await feedback.save()
    }

    return response.ok(mapFeedback(feedback))
  }
}
