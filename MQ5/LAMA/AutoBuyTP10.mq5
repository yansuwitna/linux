//+------------------------------------------------------------------+
//|                                             AutoBuyTP10.mq5      |
//+------------------------------------------------------------------+
#property strict

input double LotSize = 0.01;
input int TakeProfitPoints = 10;
input int Slippage = 10;
input ulong MagicNumber = 123456;

void OnTick()
{
   // Cek jika belum ada posisi
   if (PositionsTotal() == 0)
   {
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if (ask == 0.0) {
         Print("❌ Harga ASK tidak tersedia.");
         return;
      }

      double tp = ask + TakeProfitPoints * _Point;

      MqlTradeRequest request;
      MqlTradeResult result;
      ZeroMemory(request);

      request.action   = TRADE_ACTION_DEAL;
      request.symbol   = _Symbol;
      request.volume   = LotSize;
      request.type     = ORDER_TYPE_BUY;
      request.price    = ask;
      request.tp       = tp;
      request.deviation = Slippage;
      request.magic    = MagicNumber;
      request.comment  = "AutoBuy";

      if (!OrderSend(request, result))
      {
         Print("❌ Gagal BUY. Retcode: ", result.retcode);
      }
      else
      {
         Print("✅ BUY sukses! Ticket: ", result.order);
      }
   }
}
