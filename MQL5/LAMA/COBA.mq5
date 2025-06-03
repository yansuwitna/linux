//+------------------------------------------------------------------+
//|                                      AutoHedgeFullAveraging.mq5  |
//+------------------------------------------------------------------+
#property strict

input double LotSize = 0.01;
input int TakeProfitPoints = 10;
input int StopLossPoints = 100;
input int Slippage = 10;
input ulong MagicNumber = 445566;

input int jml_batas = 5;
int jml_buy = 0;
int jml_sell = 0;

//+------------------------------------------------------------------+
//| Expert Tick Function                                             |
//+------------------------------------------------------------------

void OnTick()
{
   int buyCount = 0;
   int sellCount = 0;

   // Hitung jumlah posisi aktif BUY dan SELL dengan magic number EA ini
   for (int i = 0; i < PositionsTotal(); i++)
   {
      if (PositionGetTicket(i) > 0 &&
          PositionGetString(POSITION_SYMBOL) == _Symbol &&
          PositionGetInteger(POSITION_MAGIC) == (long)MagicNumber)
      {
         int type = (int)PositionGetInteger(POSITION_TYPE);
         if (type == POSITION_TYPE_BUY) buyCount++;
         else if (type == POSITION_TYPE_SELL) sellCount++;
      }
   }

   // Jika tidak ada posisi, mulai dengan 1 BUY dan 1 SELL
   if (buyCount == jml_batas && sellCount == jml_batas)
   {
      jml_buy = 0;
      jml_sell = 0;
      return;
   }
   
   if (buyCount == 0 && sellCount == 0)
   {
      OpenBuy();
      OpenSell();
      return;
   }
   
   //======================
   //Jika BUY 0
   if(buyCount == 0 ){
      if(jml_buy <= jml_batas){
         OpenBuy();
         jml_buy = jml_buy + 1;
      }
      return;
   }
   
   //Jika SEL 0
   if(sellCount == 0 ){
      if(jml_sell <= jml_batas){
         OpenSell();
         jml_sell = jml_sell + 1;
      }
      return;
   }
   
}

//+------------------------------------------------------------------+
//| Fungsi membuka posisi BUY                                       |
//+------------------------------------------------------------------+
void OpenBuy()
{
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double tp = ask + TakeProfitPoints * _Point;
   double sl = ask - StopLossPoints * _Point; // SL di bawah harga BUY

   MqlTradeRequest request;
   MqlTradeResult result;
   ZeroMemory(request);

   request.action = TRADE_ACTION_DEAL;
   request.symbol = _Symbol;
   request.volume = LotSize;
   request.type = ORDER_TYPE_BUY;
   request.price = ask;
   request.tp = tp;
   //request.sl = sl; // SET SL
   request.deviation = Slippage;
   request.magic = MagicNumber;
   request.comment = "AutoBuy";

   OrderSend(request, result);
}

//+------------------------------------------------------------------+
//| Fungsi membuka posisi SELL                                      |
//+------------------------------------------------------------------+
void OpenSell()
{
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double tp = bid - TakeProfitPoints * _Point;
   double sl = bid + StopLossPoints * _Point; // SL di bawah harga BUY

   MqlTradeRequest request;
   MqlTradeResult result;
   ZeroMemory(request);

   request.action = TRADE_ACTION_DEAL;
   request.symbol = _Symbol;
   request.volume = LotSize;
   request.type = ORDER_TYPE_SELL;
   request.price = bid;
   request.tp = tp;
   //request.sl = sl; // SET SL
   request.deviation = Slippage;
   request.magic = MagicNumber;
   request.comment = "AutoSell";

   OrderSend(request, result);
}