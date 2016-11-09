package junctions

import Chisel._
import cde.Parameters

class SmiReq(val dataWidth: Int, val addrWidth: Int) extends Bundle {
  val rw = Bool()
  val addr = UInt(width = addrWidth)
  val data = Bits(width = dataWidth)

  override def cloneType =
    new SmiReq(dataWidth, addrWidth).asInstanceOf[this.type]
}

/** Simple Memory Interface IO. Used to communicate with PCR and SCR
 *  @param dataWidth the width in bits of the data field
 *  @param addrWidth the width in bits of the addr field */
class SmiIO(val dataWidth: Int, val addrWidth: Int) extends Bundle {
  val req = Decoupled(new SmiReq(dataWidth, addrWidth))
  val resp = Decoupled(Bits(width = dataWidth)).flip

  override def cloneType =
    new SmiIO(dataWidth, addrWidth).asInstanceOf[this.type]
}

abstract class SmiPeripheral extends Module {
  val dataWidth: Int
  val addrWidth: Int

  lazy val io = new SmiIO(dataWidth, addrWidth).flip
}

/** A simple sequential memory accessed through Smi */
class SmiMem(val dataWidth: Int, val memDepth: Int) extends SmiPeripheral {
  // override
  val addrWidth = log2Up(memDepth)

  val mem = SeqMem(memDepth, Bits(width = dataWidth))

  val ren = io.req.fire() && !io.req.bits.rw
  val wen = io.req.fire() && io.req.bits.rw

  when (wen) { mem.write(io.req.bits.addr, io.req.bits.data) }

  val resp_valid = Reg(init = Bool(false))

  when (io.resp.fire()) { resp_valid := Bool(false) }
  when (io.req.fire())  { resp_valid := Bool(true) }

  io.resp.valid := resp_valid
  io.resp.bits := mem.read(io.req.bits.addr, ren)
  io.req.ready := !resp_valid
}

/** Arbitrate among several Smi clients
 *  @param n the number of clients
 *  @param dataWidth Smi data width
 *  @param addrWidth Smi address width */
class SmiArbiter(val n: Int, val dataWidth: Int, val addrWidth: Int)
    extends Module {
  val io = new Bundle {
    val in = Vec(n, new SmiIO(dataWidth, addrWidth)).flip
    val out = new SmiIO(dataWidth, addrWidth)
  }

  val wait_resp = Reg(init = Bool(false))
  val choice = Reg(UInt(width = log2Up(n)))

  val req_arb = Module(new RRArbiter(new SmiReq(dataWidth, addrWidth), n))
  req_arb.io.in <> io.in.map(_.req)
  req_arb.io.out.ready := io.out.req.ready && !wait_resp

  io.out.req.bits := req_arb.io.out.bits
  io.out.req.valid := req_arb.io.out.valid && !wait_resp

  when (io.out.req.fire()) {
    choice := req_arb.io.chosen
    wait_resp := Bool(true)
  }

  when (io.out.resp.fire()) { wait_resp := Bool(false) }

  for ((resp, i) <- io.in.map(_.resp).zipWithIndex) {
    resp.bits := io.out.resp.bits
    resp.valid := io.out.resp.valid && choice === UInt(i)
  }

  io.out.resp.ready := io.in(choice).resp.ready
}

class SmiIONastiReadIOConverter(val dataWidth: Int, val addrWidth: Int)
                               (implicit p: Parameters) extends NastiModule()(p) {
  val io = new Bundle {
    val nasti = new NastiReadIO().flip
    val smi = new SmiIO(dataWidth, addrWidth)
  }

  private val maxWordsPerBeat = nastiXDataBits / dataWidth
  private val wordCountBits = log2Up(maxWordsPerBeat)
  private val byteOffBits = log2Up(dataWidth / 8)
  private val addrOffBits = addrWidth + byteOffBits

  private def calcWordCount(size: UInt): UInt =
    (UInt(1) << (size - UInt(byteOffBits))) - UInt(1)

  val (s_idle :: s_read :: s_resp :: Nil) = Enum(Bits(), 3)
  val state = Reg(init = s_idle)

  val nWords = Reg(UInt(width = wordCountBits))
  val nBeats = Reg(UInt(width = nastiXLenBits))
  val addr = Reg(UInt(width = addrWidth))
  val id = Reg(UInt(width = nastiRIdBits))

  val byteOff = Reg(UInt(width = byteOffBits))
  val recvInd = Reg(init = UInt(0, wordCountBits))
  val sendDone = Reg(init = Bool(false))

  val buffer = Reg(init = Vec.fill(maxWordsPerBeat) { Bits(0, dataWidth) })

  io.nasti.ar.ready := (state === s_idle)

  io.smi.req.valid := (state === s_read) && !sendDone
  io.smi.req.bits.rw := Bool(false)
  io.smi.req.bits.addr := addr

  io.smi.resp.ready := (state === s_read)

  io.nasti.r.valid := (state === s_resp)
  io.nasti.r.bits := NastiReadDataChannel(
    id = id,
    data = buffer.toBits,
    last = (nBeats === UInt(0)))

  when (io.nasti.ar.fire()) {
    when (io.nasti.ar.bits.size < UInt(byteOffBits)) {
      nWords := UInt(0)
    } .otherwise {
      nWords := calcWordCount(io.nasti.ar.bits.size)
    }
    nBeats := io.nasti.ar.bits.len
    addr := io.nasti.ar.bits.addr(addrOffBits - 1, byteOffBits)
    if (maxWordsPerBeat > 1)
      recvInd := io.nasti.ar.bits.addr(wordCountBits + byteOffBits - 1, byteOffBits)
    else
      recvInd := UInt(0)
    id := io.nasti.ar.bits.id
    state := s_read
  }

  when (io.smi.req.fire()) {
    addr := addr + UInt(1)
    sendDone := (nWords === UInt(0))
  }

  when (io.smi.resp.fire()) {
    recvInd := recvInd + UInt(1)
    nWords := nWords - UInt(1)
    buffer(recvInd) := io.smi.resp.bits
    when (nWords === UInt(0)) { state := s_resp }
  }

  when (io.nasti.r.fire()) {
    recvInd := UInt(0)
    sendDone := Bool(false)
    // clear all the registers in the buffer
    buffer.foreach(_ := Bits(0))
    nBeats := nBeats - UInt(1)
    state := Mux(io.nasti.r.bits.last, s_idle, s_read)
  }
}

class SmiIONastiWriteIOConverter(val dataWidth: Int, val addrWidth: Int)
                                (implicit p: Parameters) extends NastiModule()(p) {
  val io = new Bundle {
    val nasti = new NastiWriteIO().flip
    val smi = new SmiIO(dataWidth, addrWidth)
  }

  private val dataBytes = dataWidth / 8
  private val maxWordsPerBeat = nastiXDataBits / dataWidth
  private val byteOffBits = log2Floor(dataBytes)
  private val addrOffBits = addrWidth + byteOffBits
  private val nastiByteOffBits = log2Ceil(nastiXDataBits / 8)

  assert(!io.nasti.aw.valid || io.nasti.aw.bits.size >= UInt(byteOffBits),
    "Nasti size must be >= Smi size")

  val id = Reg(UInt(width = nastiWIdBits))
  val addr = Reg(UInt(width = addrWidth))
  val offset = Reg(UInt(width = nastiByteOffBits))

  def makeStrobe(offset: UInt, size: UInt, strb: UInt) = {
    val sizemask = (UInt(1) << (UInt(1) << size)) - UInt(1)
    val bytemask = strb & (sizemask << offset)
    Vec.tabulate(maxWordsPerBeat){i => bytemask(dataBytes * i)}.toBits
  }

  val size = Reg(UInt(width = nastiXSizeBits))
  val strb = Reg(UInt(width = maxWordsPerBeat))
  val data = Reg(UInt(width = nastiXDataBits))
  val last = Reg(Bool())

  val s_idle :: s_data :: s_send :: s_ack :: s_resp :: Nil = Enum(Bits(), 5)
  val state = Reg(init = s_idle)

  io.nasti.aw.ready := (state === s_idle)
  io.nasti.w.ready := (state === s_data)
  io.smi.req.valid := (state === s_send) && strb(0)
  io.smi.req.bits.rw := Bool(true)
  io.smi.req.bits.addr := addr
  io.smi.req.bits.data := data(dataWidth - 1, 0)
  io.smi.resp.ready := (state === s_ack)
  io.nasti.b.valid := (state === s_resp)
  io.nasti.b.bits := NastiWriteResponseChannel(id)

  val jump = if (maxWordsPerBeat > 1)
    PriorityMux(strb(maxWordsPerBeat - 1, 1),
      (1 until maxWordsPerBeat).map(UInt(_)))
    else UInt(1)

  when (io.nasti.aw.fire()) {
    if (dataWidth == nastiXDataBits) {
      addr := io.nasti.aw.bits.addr(addrOffBits - 1, byteOffBits)
    } else {
      addr := Cat(io.nasti.aw.bits.addr(addrOffBits - 1, nastiByteOffBits),
                  UInt(0, nastiByteOffBits - byteOffBits))
    }
    offset := io.nasti.aw.bits.addr(nastiByteOffBits - 1, 0)
    id := io.nasti.aw.bits.id
    size := io.nasti.aw.bits.size
    last := Bool(false)
    state := s_data
  }

  when (io.nasti.w.fire()) {
    last := io.nasti.w.bits.last
    strb := makeStrobe(offset, size, io.nasti.w.bits.strb)
    data := io.nasti.w.bits.data
    state := s_send
  }

  when (state === s_send) {
    when (io.smi.req.ready || !strb(0)) {
      strb := strb >> jump
      data := data >> Cat(jump, UInt(0, log2Up(dataWidth)))
      addr := addr + jump
      when (strb(0)) { state := s_ack }
    }
  }

  when (io.smi.resp.fire()) {
    state := Mux(strb === UInt(0),
              Mux(last, s_resp, s_data), s_send)
  }

  when (io.nasti.b.fire()) { state := s_idle }
}

/** Convert Nasti protocol to Smi protocol */
class SmiIONastiIOConverter(val dataWidth: Int, val addrWidth: Int)
                           (implicit p: Parameters) extends NastiModule()(p) {
  val io = new Bundle {
    val nasti = (new NastiIO).flip
    val smi = new SmiIO(dataWidth, addrWidth)
  }

  require(isPow2(dataWidth), "SMI data width must be power of 2")
  require(dataWidth <= nastiXDataBits,
    "SMI data width must be less than or equal to NASTI data width")

  val reader = Module(new SmiIONastiReadIOConverter(dataWidth, addrWidth))
  reader.io.nasti <> io.nasti

  val writer = Module(new SmiIONastiWriteIOConverter(dataWidth, addrWidth))
  writer.io.nasti <> io.nasti

  val arb = Module(new SmiArbiter(2, dataWidth, addrWidth))
  arb.io.in(0) <> reader.io.smi
  arb.io.in(1) <> writer.io.smi
  io.smi <> arb.io.out
}
