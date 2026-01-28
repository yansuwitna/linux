//+------------------------------------------------------------------+
//|                                      AutoHedgeTP10.mq5           |
//+------------------------------------------------------------------+
#property strict

input double LotSize = 0.02;
input int TakeProfitPoints = 10;
input int Slippage = 10;
input ulong MagicNumber = 112233;

bool alreadyOpened = false;

//+------------------------------------------------------------------+
//| Expert Tick Function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   int buyCount = 0;
   int sellCount = 0;

   // Hitung posisi aktif BUY dan SELL dengan Magic Number yang sama
   for (int i = 0; i < PositionsTotal(); i++)
   {
      if (PositionGetTicket(i) > 0)
      {
         if (PositionGetInteger(POSITION_MAGIC) == (long)MagicNumber &&
             PositionGetString(POSITION_SYMBOL) == _Symbol)
         {
            if (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
               buyCount++;
            else if (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
               sellCount++;
         }
      }
   }

   // Jika belum ada posisi aktif, buka BUY dan SELL secara bersamaan
   if (buyCount == 0 && sellCount == 0)
   {
      OpenBuy();
      OpenSell();
   }
}

//+------------------------------------------------------------------+
//| Fungsi membuka posisi BUY                                       |
//+------------------------------------------------------------------+
void OpenBuy()
{
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double tp = ask + TakeProfitPoints * _Point;

   MqlTradeRequest request;
   MqlTradeResult result;
   ZeroMemory(request);

   request.action = TRADE_ACTION_DEAL;
   request.symbol = _Symbol;
   request.volume = LotSize;
   request.type = ORDER_TYPE_BUY;
   request.price = ask;
   request.tp = tp;
   request.deviation = Slippage;
   request.magic = MagicNumber;
   request.comment = "AutoBuy";

   OrderSend(request, result);
   if (result.retcode == TRADE_RETCODE_DONE)
      Print("✅ BUY berhasil. Ticket: ", result.order);
   else
      Print("❌ BUY gagal. Retcode: ", result.retcode);
}

//+------------------------------------------------------------------+
//| Fungsi membuka posisi SELL                                      |
//+------------------------------------------------------------------+
void OpenSell()
{
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double tp = bid - TakeProfitPoints * _Point;

   MqlTradeRequest request;
   MqlTradeResult result;
   ZeroMemory(request);

   request.action = TRADE_ACTION_DEAL;
   request.symbol = _Symbol;
   request.volume = LotSize;
   request.type = ORDER_TYPE_SELL;
   request.price = bid;
   request.tp = tp;
   request.deviation = Slippage;
   request.magic = MagicNumber;
   request.comment = "AutoSell";

   OrderSend(request, result);
   if (result.retcode == TRADE_RETCODE_DONE)
      Print("✅ SELL berhasil. Ticket: ", result.order);
   else
      Print("❌ SELL gagal. Retcode: ", result.retcode);
}
