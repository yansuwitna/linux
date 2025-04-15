//+------------------------------------------------------------------+
//|                                      AutoHedgeFullAveraging.mq5  |
//+------------------------------------------------------------------+
#property strict

input double LotSize = 0.01;
input int TakeProfitPoints = 10;
input int Slippage = 10;
input ulong MagicNumber = 445566;

// Batas kerugian bertingkat (dalam poin)
input int LossLevel1 = 50;
input int LossLevel2 = 60;
input int LossLevel3 = 70;
input int LossLevel4 = 80;
input int LossLevel5 = 90;
input int LossLevel6 = 100;

int LossLevels[] = {LossLevel1, LossLevel2, LossLevel3, LossLevel4, LossLevel5, LossLevel6};

//+------------------------------------------------------------------+
//| Expert Tick Function                                             |
//+------------------------------------------------------------------+
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
   if (buyCount == 0 && sellCount == 0)
   {
      OpenBuy();
      OpenSell();
      return;
   }

   // Cek BUY dan SELL untuk averaging jika rugi mendekati loss level
   CheckBuyAveraging();
   CheckSellAveraging();
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
}

//+------------------------------------------------------------------+
//| Fungsi averaging posisi BUY                                     |
//+------------------------------------------------------------------+
void CheckBuyAveraging()
{
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   for (int i = 0; i < PositionsTotal(); i++)
   {
      if (PositionGetTicket(i) > 0 &&
          PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY &&
          PositionGetString(POSITION_SYMBOL) == _Symbol &&
          PositionGetInteger(POSITION_MAGIC) == (long)MagicNumber)
      {
         double entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
         double lossPoint = (entryPrice - bid) / _Point;

         for (int j = 0; j < ArraySize(LossLevels); j++)
         {
            int level = LossLevels[j];
            if (MathAbs(lossPoint - level) < 1.0 && !AveragingExistsAtLevel(level, POSITION_TYPE_BUY))
            {
               Print("📉 BUY floating loss mendekati -", level, " → Buka BUY baru");
               OpenBuy();
               return;
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Fungsi averaging posisi SELL                                    |
//+------------------------------------------------------------------+
void CheckSellAveraging()
{
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   for (int i = 0; i < PositionsTotal(); i++)
   {
      if (PositionGetTicket(i) > 0 &&
          PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL &&
          PositionGetString(POSITION_SYMBOL) == _Symbol &&
          PositionGetInteger(POSITION_MAGIC) == (long)MagicNumber)
      {
         double entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
         double lossPoint = (ask - entryPrice) / _Point;

         for (int j = 0; j < ArraySize(LossLevels); j++)
         {
            int level = LossLevels[j];
            if (MathAbs(lossPoint - level) < 1.0 && !AveragingExistsAtLevel(level, POSITION_TYPE_SELL))
            {
               Print("📈 SELL floating loss mendekati -", level, " → Buka SELL baru");
               OpenSell();
               return;
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Cek apakah sudah ada posisi di level averaging tertentu         |
//+------------------------------------------------------------------+
bool AveragingExistsAtLevel(int level, int positionType)
{
   double priceNow = (positionType == POSITION_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                                         : SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   for (int i = 0; i < PositionsTotal(); i++)
   {
      if (PositionGetTicket(i) > 0 &&
          PositionGetString(POSITION_SYMBOL) == _Symbol &&
          PositionGetInteger(POSITION_TYPE) == positionType &&
          PositionGetInteger(POSITION_MAGIC) == (long)MagicNumber)
      {
         double entry = PositionGetDouble(POSITION_PRICE_OPEN);
         double diff = (positionType == POSITION_TYPE_BUY)
                       ? (entry - priceNow) / _Point
                       : (priceNow - entry) / _Point;

         if (MathAbs(diff - level) < 1.0)
            return true;
      }
   }
   return false;
}
