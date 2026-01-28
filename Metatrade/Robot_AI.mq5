#property strict
#include <Trade\Trade.mqh>
CTrade trade;

// ==== INPUT ====
input double LotSize        = 0.01;
input bool useSL            = true;
input bool useTP            = true;
input double SL_Multiplier  = 10;
input double TP_Multiplier  = 20;
input int TrailingStart     = 10;
input int TrailingStep      = 5;
input int MaxTrades         = 1;
input bool useMartingale    = true;
input double MinDiffKD      = 2.0;  // Minimum selisih %K - %D
input int DelaySeconds      = 10;   // Waktu jeda antar transaksi dalam detik setelah open/close

// === STOCHASTIC ===
input int KPeriod = 8;
input int DPeriod = 3;
input int Slowing = 3;
input ENUM_MA_METHOD MA_Method = MODE_SMA;
input ENUM_STO_PRICE PriceField = STO_LOWHIGH;

int handleStoch;
datetime lastTradeTime = 0;

// ==== UTIL ====
double GetMartingaleLot(int index)
{
   double base = LotSize;
   if (useMartingale) base *= MathPow(2, index);
   double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   return MathMax(minLot, MathMin(NormalizeDouble(base, 2), maxLot));
}

int CountPositions(string symbol)
{
   int total = 0;
   for (int i = 0; i < PositionsTotal(); i++)
      if (PositionGetTicket(i) > 0 && PositionGetString(POSITION_SYMBOL) == symbol)
         total++;
   return total;
}

bool IsBuySignal()
{
   double k[], d[];
   if (CopyBuffer(handleStoch, 0, 0, 1, k) < 1 || CopyBuffer(handleStoch, 1, 0, 1, d) < 1)
      return false;
   double diff = MathAbs(k[0] - d[0]);
   return (k[0] > d[0] && diff >= MinDiffKD);
}

bool IsSellSignal()
{
   double k[], d[];
   if (CopyBuffer(handleStoch, 0, 0, 1, k) < 1 || CopyBuffer(handleStoch, 1, 0, 1, d) < 1)
      return false;
   double diff = MathAbs(k[0] - d[0]);
   return (k[0] < d[0] && diff >= MinDiffKD);
}

int OnInit()
{
   handleStoch = iStochastic(_Symbol, _Period, KPeriod, DPeriod, Slowing, MA_Method, PriceField);
   if (handleStoch == INVALID_HANDLE)
   {
      Print("\u274c Gagal membuat handle Stochastic");
      return INIT_FAILED;
   }
   return INIT_SUCCEEDED;
}

void OnTick()
{
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   double spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) * point;
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   double slDist = spread * SL_Multiplier;
   double tpDist = spread * TP_Multiplier;

   int posisi = CountPositions(_Symbol);
   double lot = GetMartingaleLot(MathMax(0, posisi - 1));

   // ENTRY dengan jeda waktu setelah open/close
   if ((TimeCurrent() - lastTradeTime >= DelaySeconds) && posisi == 0)
   {
      double open = iOpen(_Symbol, _Period, 0);
      double close = iClose(_Symbol, _Period, 0);
      double sl = 0, tp = 0;

      if (close > open && IsBuySignal())
      {
         sl = useSL ? NormalizeDouble(ask - slDist, digits) : 0;
         tp = useTP ? NormalizeDouble(ask + tpDist, digits) : 0;
         if (trade.Buy(lot, _Symbol, ask, sl, tp, "Buy K>D & diff ok"))
            lastTradeTime = TimeCurrent();
      }
      else if (close < open && IsSellSignal())
      {
         sl = useSL ? NormalizeDouble(bid + slDist, digits) : 0;
         tp = useTP ? NormalizeDouble(bid - tpDist, digits) : 0;
         if (trade.Sell(lot, _Symbol, bid, sl, tp, "Sell K<D & diff ok"))
            lastTradeTime = TimeCurrent();
      }
   }

   // Perbarui lastTradeTime jika posisi ditutup
   if (posisi == 0 && lastTradeTime != 0 && TimeCurrent() - lastTradeTime >= DelaySeconds)
      lastTradeTime = TimeCurrent();

   // TRAILING + INFO
   string info = "";
   for (int i = 0; i < PositionsTotal(); i++)
   {
      if (PositionGetTicket(i) > 0 && PositionGetString(POSITION_SYMBOL) == _Symbol)
      {
         long type = PositionGetInteger(POSITION_TYPE);
         double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
         double sl = PositionGetDouble(POSITION_SL);
         double tp = PositionGetDouble(POSITION_TP);
         double profit = PositionGetDouble(POSITION_PROFIT);
         ulong ticket = PositionGetInteger(POSITION_TICKET);
         double current = (type == POSITION_TYPE_BUY) ? bid : ask;

         if (type == POSITION_TYPE_BUY && (current - openPrice) >= TrailingStart * point)
         {
            double new_sl = NormalizeDouble(current - TrailingStep * point, digits);
            double new_tp = NormalizeDouble(tp + TrailingStep * point, digits);
            if (useSL && new_sl > sl)
               trade.PositionModify(ticket, new_sl, useTP ? new_tp : tp);
         }
         if (type == POSITION_TYPE_SELL && (openPrice - current) >= TrailingStart * point)
         {
            double new_sl = NormalizeDouble(current + TrailingStep * point, digits);
            double new_tp = NormalizeDouble(tp - TrailingStep * point, digits);
            if (useSL && (new_sl < sl || sl == 0))
               trade.PositionModify(ticket, new_sl, useTP ? new_tp : tp);
         }

         info += StringFormat("Posisi %s\nOpen: %.%df\nSL: %.%df TP: %.%df\nProfit: %.2f USD\n\n",
            (type == POSITION_TYPE_BUY ? "BUY" : "SELL"), digits, openPrice, digits, sl, digits, tp, profit);
      }
   }

   // === Penanda Candle Bullish/Bearish ===
   for (int i = 0; i < 5 && i < Bars(_Symbol, _Period); i++)
   {
      double open = iOpen(_Symbol, _Period, i);
      double close = iClose(_Symbol, _Period, i);
      double high = iHigh(_Symbol, _Period, i);
      double low = iLow(_Symbol, _Period, i);
      datetime time = iTime(_Symbol, _Period, i);

      string nameBull = "ArrowBull_" + IntegerToString(i);
      string nameBear = "ArrowBear_" + IntegerToString(i);
      ObjectDelete(0, nameBull);
      ObjectDelete(0, nameBear);

      if (close > open)
      {
         ObjectCreate(0, nameBull, OBJ_ARROW, 0, time, low - 5 * point);
         ObjectSetInteger(0, nameBull, OBJPROP_ARROWCODE, 233);
         ObjectSetInteger(0, nameBull, OBJPROP_COLOR, clrLime);
      }
      else if (close < open)
      {
         ObjectCreate(0, nameBear, OBJ_ARROW, 0, time, high + 5 * point);
         ObjectSetInteger(0, nameBear, OBJPROP_ARROWCODE, 234);
         ObjectSetInteger(0, nameBear, OBJPROP_COLOR, clrRed);
      }
   }

   // === Penanda Stochastic %K vs %D dengan syarat MinDiffKD ===
   double k[], d[];
   if (CopyBuffer(handleStoch, 0, 0, 2, k) == 2 && CopyBuffer(handleStoch, 1, 0, 2, d) == 2)
   {
      datetime time = iTime(_Symbol, _Period, 0);
      double price = iClose(_Symbol, _Period, 0);
      double diff = MathAbs(k[0] - d[0]);

      string nameCross = "StochKD_" + TimeToString(time, TIME_MINUTES);
      ObjectDelete(0, nameCross);

      if (diff >= MinDiffKD)
      {
         if (k[0] > d[0])
         {
            ObjectCreate(0, nameCross, OBJ_ARROW, 0, time, price - 10 * point);
            ObjectSetInteger(0, nameCross, OBJPROP_ARROWCODE, 241);
            ObjectSetInteger(0, nameCross, OBJPROP_COLOR, clrBlue);
         }
         else if (k[0] < d[0])
         {
            ObjectCreate(0, nameCross, OBJ_ARROW, 0, time, price + 10 * point);
            ObjectSetInteger(0, nameCross, OBJPROP_ARROWCODE, 242);
            ObjectSetInteger(0, nameCross, OBJPROP_COLOR, clrOrangeRed);
         }
      }
   }

   // INFO PANEL: %K, %D, Selisih
   string stochInfo = "";
   if (CopyBuffer(handleStoch, 0, 0, 1, k) == 1 && CopyBuffer(handleStoch, 1, 0, 1, d) == 1)
   {
      double selisih = MathAbs(k[0] - d[0]);
      stochInfo = StringFormat("\ud83d\udd01 Stochastic\nK: %.2f\nD: %.2f\n\u0394(K-D): %.2f\nMin\u0394: %.2f",
         k[0], d[0], selisih, MinDiffKD);
   }

   Comment((info == "") ? stochInfo : info + "\n" + stochInfo);
}
