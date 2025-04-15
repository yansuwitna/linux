//+------------------------------------------------------------------+
//|                                             AutoSellTP10.mq5     |
//+------------------------------------------------------------------+
#property strict

input double LotSize = 0.01;
input int TakeProfitPoints = 10;
input int Slippage = 10;
input ulong MagicNumber = 654321;

void OnTick()
{
   // Cek jika belum ada posisi terbuka
   if (PositionsTotal() == 0)
   {
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if (bid == 0.0) {
         Print("❌ Harga BID tidak tersedia.");
         return;
      }

      double tp = bid - TakeProfitPoints * _Point;

      MqlTradeRequest request;
      MqlTradeResult result;
      ZeroMemory(request);

      request.action   = TRADE_ACTION_DEAL;
      request.symbol   = _Symbol;
      request.volume   = LotSize;
      request.type     = ORDER_TYPE_SELL;
      request.price    = bid;
      request.tp       = tp;
      request.deviation = Slippage;
      request.magic    = MagicNumber;
      request.comment  = "AutoSell";

      if (!OrderSend(request, result))
      {
         Print("❌ Gagal SELL. Retcode: ", result.retcode);
      }
      else
      {
         Print("✅ SELL sukses! Ticket: ", result.order);
      }
   }
}
