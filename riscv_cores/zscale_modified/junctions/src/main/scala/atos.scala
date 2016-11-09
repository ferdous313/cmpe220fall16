package junctions

import Chisel._
import scala.math.max
import cde.{Parameters, Field}

trait HasAtosParameters extends HasNastiParameters {
  // round up to a multiple of 32
  def roundup(n: Int) = 32 * ((n - 1) / 32 + 1)

  val atosUnionBits = max(
    nastiXIdBits + nastiXDataBits + nastiWStrobeBits + 1,
    nastiXIdBits + nastiXBurstBits +
    nastiXSizeBits + nastiXLenBits + nastiXAddrBits)
  val atosIdBits = nastiXIdBits
  val atosTypBits = 2
  val atosRespBits = nastiXRespBits
  val atosDataBits = nastiXDataBits

  val atosAddrOffset = atosIdBits
  val atosLenOffset = atosIdBits + nastiXAddrBits
  val atosSizeOffset = atosLenOffset + nastiXLenBits
  val atosBurstOffset = atosSizeOffset + nastiXSizeBits

  val atosDataOffset = atosIdBits
  val atosStrobeOffset = nastiXDataBits + atosIdBits
  val atosLastOffset = atosStrobeOffset + nastiWStrobeBits

  val atosRequestBits = roundup(atosTypBits + atosUnionBits)
  val atosResponseBits = roundup(atosTypBits + atosIdBits + atosRespBits + atosDataBits + 1)
  val atosRequestBytes = atosRequestBits / 8
  val atosResponseBytes = atosResponseBits / 8
  val atosRequestWords = atosRequestBytes / 4
  val atosResponseWords = atosResponseBytes / 4
}

abstract class AtosModule(implicit val p: Parameters)
  extends Module with HasAtosParameters
abstract class AtosBundle(implicit val p: Parameters)
  extends ParameterizedBundle()(p) with HasAtosParameters

object AtosRequest {
  def arType = UInt("b00")
  def awType = UInt("b01")
  def wType  = UInt("b10")

  def apply(typ: UInt, union: UInt)(implicit p: Parameters): AtosRequest = {
    val areq = Wire(new AtosRequest)
    areq.typ := typ
    areq.union := union
    areq
  }

  def apply(ar: NastiReadAddressChannel)(implicit p: Parameters): AtosRequest =
    apply(arType, Cat(ar.burst, ar.size, ar.len, ar.addr, ar.id))

  def apply(aw: NastiWriteAddressChannel)(implicit p: Parameters): AtosRequest =
    apply(awType, Cat(aw.burst, aw.size, aw.len, aw.addr, aw.id))

  def apply(w: NastiWriteDataChannel)(implicit p: Parameters): AtosRequest =
    apply(wType, Cat(w.last, w.strb, w.data, w.id))
}

class AtosRequest(implicit p: Parameters)
    extends AtosBundle()(p) with Serializable {
  val typ = UInt(width = atosTypBits)
  val union = UInt(width = atosUnionBits)

  def burst(dummy: Int = 0) =
    union(atosUnionBits - 1, atosBurstOffset)

  def size(dummy: Int = 0) =
    union(atosBurstOffset - 1, atosSizeOffset)

  def len(dummy: Int = 0) =
    union(atosSizeOffset - 1, atosLenOffset)

  def addr(dummy: Int = 0) =
    union(atosLenOffset - 1, atosAddrOffset)

  def id(dummy: Int = 0) =
    union(atosIdBits - 1, 0)

  def data(dummy: Int = 0) =
    union(atosStrobeOffset - 1, atosDataOffset)

  def strb(dummy: Int = 0) =
    union(atosLastOffset - 1, atosStrobeOffset)

  def last(dummy: Int = 0) =
    union(atosLastOffset)

  def has_addr(dummy: Int = 0) =
    typ === AtosRequest.arType || typ === AtosRequest.awType

  def has_data(dummy: Int = 0) =
    typ === AtosRequest.wType

  def is_last(dummy: Int = 0) =
    typ === AtosRequest.arType || (typ === AtosRequest.wType && last())

  def nbits: Int = atosRequestBits

  def resp_len(dummy: Int = 0) =
    MuxLookup(typ, UInt(0), Seq(
      AtosRequest.arType -> (len() + UInt(1)),
      AtosRequest.awType -> UInt(1)))
}

object AtosResponse {
  def rType = UInt("b00")
  def bType = UInt("b01")

  def apply(typ: UInt, id: UInt, resp: UInt, data: UInt, last: Bool)
      (implicit p: Parameters): AtosResponse = {
    val aresp = Wire(new AtosResponse)
    aresp.typ := typ
    aresp.id := id
    aresp.resp := resp
    aresp.data := data
    aresp.last := last
    aresp
  }

  def apply(r: NastiReadDataChannel)(implicit p: Parameters): AtosResponse =
    apply(rType, r.id, r.resp, r.data, r.last)

  def apply(b: NastiWriteResponseChannel)(implicit p: Parameters): AtosResponse =
    apply(bType, b.id, b.resp, UInt(0), Bool(false))
}

class AtosResponse(implicit p: Parameters)
    extends AtosBundle()(p) with Serializable {
  val typ = UInt(width = atosTypBits)
  val id = UInt(width = atosIdBits)
  val resp = UInt(width = atosRespBits)
  val last = Bool()
  val data = UInt(width = atosDataBits)

  def has_data(dummy: Int = 0) = typ === AtosResponse.rType

  def is_last(dummy: Int = 0) = !has_data() || last

  def nbits: Int = atosResponseBits
}

class AtosIO(implicit p: Parameters) extends AtosBundle()(p) {
  val req = Decoupled(new AtosRequest)
  val resp = Decoupled(new AtosResponse).flip
}

class AtosRequestEncoder(implicit p: Parameters) extends AtosModule()(p) {
  val io = new Bundle {
    val ar = Decoupled(new NastiReadAddressChannel).flip
    val aw = Decoupled(new NastiWriteAddressChannel).flip
    val w  = Decoupled(new NastiWriteDataChannel).flip
    val req = Decoupled(new AtosRequest)
  }

  val writing = Reg(init = Bool(false))

  io.ar.ready := !writing && io.req.ready
  io.aw.ready := !writing && !io.ar.valid && io.req.ready
  io.w.ready  := writing && io.req.ready

  io.req.valid := Mux(writing, io.w.valid, io.ar.valid || io.aw.valid)
  io.req.bits := Mux(writing, AtosRequest(io.w.bits),
    Mux(io.ar.valid, AtosRequest(io.ar.bits), AtosRequest(io.aw.bits)))

  when (io.aw.fire()) { writing := Bool(true) }
  when (io.w.fire() && io.w.bits.last) { writing := Bool(false) }
}

class AtosResponseDecoder(implicit p: Parameters) extends AtosModule()(p) {
  val io = new Bundle {
    val resp = Decoupled(new AtosResponse).flip
    val b = Decoupled(new NastiWriteResponseChannel)
    val r = Decoupled(new NastiReadDataChannel)
  }

  val is_b = io.resp.bits.typ === AtosResponse.bType
  val is_r = io.resp.bits.typ === AtosResponse.rType

  io.b.valid := io.resp.valid && is_b
  io.b.bits := NastiWriteResponseChannel(
    id = io.resp.bits.id,
    resp = io.resp.bits.resp)

  io.r.valid := io.resp.valid && is_r
  io.r.bits := NastiReadDataChannel(
    id = io.resp.bits.id,
    data = io.resp.bits.data,
    last = io.resp.bits.last,
    resp = io.resp.bits.resp)

  io.resp.ready := (is_b && io.b.ready) || (is_r && io.r.ready)
}

class AtosClientConverter(implicit p: Parameters) extends AtosModule()(p) {
  val io = new Bundle {
    val nasti = (new NastiIO).flip
    val atos = new AtosIO
  }

  val req_enc = Module(new AtosRequestEncoder)
  req_enc.io.ar <> io.nasti.ar
  req_enc.io.aw <> io.nasti.aw
  req_enc.io.w  <> io.nasti.w
  io.atos.req <> req_enc.io.req

  val resp_dec = Module(new AtosResponseDecoder)
  resp_dec.io.resp <> io.atos.resp
  io.nasti.b <> resp_dec.io.b
  io.nasti.r <> resp_dec.io.r
}

class AtosRequestDecoder(implicit p: Parameters) extends AtosModule()(p) {
  val io = new Bundle {
    val req = Decoupled(new AtosRequest).flip
    val ar = Decoupled(new NastiReadAddressChannel)
    val aw = Decoupled(new NastiWriteAddressChannel)
    val w  = Decoupled(new NastiWriteDataChannel)
  }

  val is_ar = io.req.bits.typ === AtosRequest.arType
  val is_aw = io.req.bits.typ === AtosRequest.awType
  val is_w  = io.req.bits.typ === AtosRequest.wType

  io.ar.valid := io.req.valid && is_ar
  io.ar.bits := NastiReadAddressChannel(
    id = io.req.bits.id(),
    addr = io.req.bits.addr(),
    size = io.req.bits.size(),
    len = io.req.bits.len(),
    burst = io.req.bits.burst())

  io.aw.valid := io.req.valid && is_aw
  io.aw.bits := NastiWriteAddressChannel(
    id = io.req.bits.id(),
    addr = io.req.bits.addr(),
    size = io.req.bits.size(),
    len = io.req.bits.len(),
    burst = io.req.bits.burst())

  io.w.valid := io.req.valid && is_w
  io.w.bits := NastiWriteDataChannel(
    id = io.req.bits.id(),
    data = io.req.bits.data(),
    strb = Some(io.req.bits.strb()),
    last = io.req.bits.last())

  io.req.ready := (io.ar.ready && is_ar) ||
                  (io.aw.ready && is_aw) ||
                  (io.w.ready  && is_w)
}

class AtosResponseEncoder(implicit p: Parameters) extends AtosModule()(p) {
  val io = new Bundle {
    val b = Decoupled(new NastiWriteResponseChannel).flip
    val r = Decoupled(new NastiReadDataChannel).flip
    val resp = Decoupled(new AtosResponse)
  }

  val locked = Reg(init = Bool(false))

  io.resp.valid := (io.b.valid && !locked) || io.r.valid
  io.resp.bits := Mux(io.r.valid,
    AtosResponse(io.r.bits), AtosResponse(io.b.bits))

  io.b.ready := !locked && !io.r.valid && io.resp.ready
  io.r.ready := io.resp.ready

  when (io.r.fire() && !io.r.bits.last) { locked := Bool(true) }
  when (io.r.fire() && io.r.bits.last) { locked := Bool(false) }
}

class AtosManagerConverter(implicit p: Parameters) extends AtosModule()(p) {
  val io = new Bundle {
    val atos = (new AtosIO).flip
    val nasti = new NastiIO
  }

  val req_dec = Module(new AtosRequestDecoder)
  val resp_enc = Module(new AtosResponseEncoder)

  req_dec.io.req <> io.atos.req
  io.atos.resp <> resp_enc.io.resp

  io.nasti.ar <> req_dec.io.ar
  io.nasti.aw <> req_dec.io.aw
  io.nasti.w  <> req_dec.io.w

  resp_enc.io.b <> io.nasti.b
  resp_enc.io.r <> io.nasti.r
}

class AtosSerializedIO(w: Int)(implicit p: Parameters) extends ParameterizedBundle()(p) {
  val req = Decoupled(Bits(width = w))
  val resp = Decoupled(Bits(width = w)).flip
  val clk = Bool(OUTPUT)
  val clk_edge = Bool(OUTPUT)
  override def cloneType = new AtosSerializedIO(w)(p).asInstanceOf[this.type]
}

class AtosSerdes(w: Int)(implicit p: Parameters) extends AtosModule()(p) {
  val io = new Bundle {
    val wide = (new AtosIO).flip
    val narrow = new AtosSerializedIO(w)
  }

  val ser = Module(new Serializer(w, new AtosRequest))
  ser.io.in <> io.wide.req
  io.narrow.req <> ser.io.out

  val des = Module(new Deserializer(w, new AtosResponse))
  des.io.in <> io.narrow.resp
  io.wide.resp <> des.io.out
}

class AtosDesser(w: Int)(implicit p: Parameters) extends AtosModule()(p) {
  val io = new Bundle {
    val narrow = new AtosSerializedIO(w).flip
    val wide = new AtosIO
  }

  val des = Module(new Deserializer(w, new AtosRequest))
  des.io.in <> io.narrow.req
  io.wide.req <> des.io.out

  val ser = Module(new Serializer(w, new AtosResponse))
  ser.io.in <> io.wide.resp
  io.narrow.resp <> ser.io.out
}
