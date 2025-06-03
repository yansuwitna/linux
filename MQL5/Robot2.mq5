/* 
| Fitur                                                         | Status |
| ------------------------------------------------------------- | ------ |
| Entry berdasarkan candle berjalan                             | ✅      |
| SL/TP berdasarkan spread × multiplier                         | ✅      |
| Averaging berdasarkan harga posisi terakhir                   | ✅      |
| ❗ Lot Martingale dikali 2 setiap posisi baru (bisa dimatikan) | ✅      |
| Trailing Stop aktif untuk semua posisi                        | ✅      |
| TP otomatis bergerak menjauh saat trailing aktif              | ✅      |
| Input LotSize, MaxTrades, pengganda spread SL/TP              | ✅      |
| Panel info aktif di chart (`Comment()`)                       | ✅      |
| Multi-chart dan multi-symbol                                  | ✅      |
| Panah penanda candle bullish dan bearish                      | ✅      |
| Validasi Stochastic untuk Buy/Sell                            | ✅      |
*/


// ==== [Header & Properti] ====
#property strict
#include <Trade\Trade.mqh>
CTrade trade;

// ==== [Input Parameter] ====
input int MaxCandles          = 10;
input double LotSize          = 0.01;
input bool useMartingale      = true;
input int TrailingStart       = 10;
input int TrailingStep        = 5;
input double SL_Multiplier    = 10;
input double TP_Multiplier    = 205;
input bool useSL              = true;
input bool useTP              = true;
input double RepeatMultiplier = 2.0;
input int MaxTrades           = 1;

// === STOCHASTIC SETTING ===
input int KPeriod = 8;
input int DPeriod = 3;
input int Slowing = 3;
input ENUM_MA_METHOD MA_Method = MODE_SMA;
input ENUM_STO_PRICE PriceField = STO_LOWHIGH;
input double StochUpper = 80.0;
input double StochLower = 20.0;

int handleStoch;

// ==== [Function Hitung Posisi] ====
int CountPositions(string symbol)
{
   int total = 0;
   for (int i = 0; i < PositionsTotal(); i++)
      if (PositionGetTicket(i) > 0 && PositionGetString(POSITION_SYMBOL) == symbol)
         total++;
   return total;
}

double GetMartingaleLot(int index)
{
   double base = LotSize;
   if (useMartingale)
      base *= MathPow(2, index);
   double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   return MathMax(minLot, MathMin(NormalizeDouble(base, 2), maxLot));
}

bool IsBuySignal()
{
   double main[], signal[];
   if (CopyBuffer(handleStoch, 0, 0, 1, main) < 1 || CopyBuffer(handleStoch, 1, 0, 1, signal) < 1)
      return false;
   return (main[0] < StochLower && main[0] > signal[0]);
}

bool IsSellSignal()
{
   double main[], signal[];
   if (CopyBuffer(handleStoch, 0, 0, 1, main) < 1 || CopyBuffer(handleStoch, 1, 0, 1, signal) < 1)
      return false;
   return (main[0] > StochUpper && main[0] < signal[0]);
}

// ==== [OnInit] ====
int OnInit()
{
   Comment("");
   handleStoch = iStochastic(_Symbol, _Period, KPeriod, DPeriod, Slowing, MA_Method, PriceField);
   if (handleStoch == INVALID_HANDLE)
   {
      Print("❌ Gagal membuat handle Stochastic");
      return INIT_FAILED;
   }
   return INIT_SUCCEEDED;
}

// ==== [OnTick] ====
void OnTick()
{
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   double spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) * point;

   double slDistance = spread * SL_Multiplier;
   double tpDistance = spread * TP_Multiplier;
   double repeatDistance = spread * RepeatMultiplier;
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   // 🎯 Tampilkan panah candle
   for (int i = 0; i < MaxCandles && i < Bars(_Symbol, _Period); i++)
   {
      double open = iOpen(_Symbol, _Period, i);
      double close = iClose(_Symbol, _Period, i);
      double high = iHigh(_Symbol, _Period, i);
      double low = iLow(_Symbol, _Period, i);
      datetime time = iTime(_Symbol, _Period, i);

      string nameBull = "ArrowBull_" + _Symbol + "_" + IntegerToString(i);
      string nameBear = "ArrowBear_" + _Symbol + "_" + IntegerToString(i);
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

   int posisi = CountPositions(_Symbol);
   double lot = GetMartingaleLot(MathMax(0, posisi - 1));

   // Entry Pertama
   if (posisi == 0)
   {
      double open = iOpen(_Symbol, _Period, 0);
      double close = iClose(_Symbol, _Period, 0);
      double sl, tp;

      if (close > open && IsBuySignal())
      {
         sl = useSL ? NormalizeDouble(ask - slDistance, digits) : 0.0;
         tp = useTP ? NormalizeDouble(ask + tpDistance, digits) : 0.0;
         trade.Buy(lot, _Symbol, ask, sl, tp, "Buy Bullish");
      }
      else if (close < open && IsSellSignal())
      {
         sl = useSL ? NormalizeDouble(bid + slDistance, digits) : 0.0;
         tp = useTP ? NormalizeDouble(bid - tpDistance, digits) : 0.0;
         trade.Sell(lot, _Symbol, bid, sl, tp, "Sell Bearish");
      }
   }

   // === Averaging + Trailing ===
   datetime lastOpenTime = 0;
   double lastOpenPrice = 0.0;
   long lastType = -1;
   string info = "";

   for (int i = 0; i < PositionsTotal(); i++)
   {
      if (PositionGetTicket(i) > 0 && PositionGetString(POSITION_SYMBOL) == _Symbol)
      {
         datetime opentime = (datetime)PositionGetInteger(POSITION_TIME);
         if (opentime > lastOpenTime)
         {
            lastOpenTime = opentime;
            lastOpenPrice = PositionGetDouble(POSITION_PRICE_OPEN);
            lastType = PositionGetInteger(POSITION_TYPE);
         }

         long type = PositionGetInteger(POSITION_TYPE);
         double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
         double sl = PositionGetDouble(POSITION_SL);
         double tp = PositionGetDouble(POSITION_TP);
         ulong ticket = PositionGetInteger(POSITION_TICKET);
         double profit = PositionGetDouble(POSITION_PROFIT);
         double currentPrice = (type == POSITION_TYPE_BUY) ? bid : ask;

         if (type == POSITION_TYPE_BUY && (currentPrice - openPrice) >= TrailingStart * point)
         {
            double new_sl = NormalizeDouble(currentPrice - TrailingStep * point, digits);
            double new_tp = NormalizeDouble(tp + TrailingStart * point, digits);
            if (useSL && new_sl > sl)
               trade.PositionModify(ticket, new_sl, useTP ? new_tp : tp);
         }

         if (type == POSITION_TYPE_SELL && (openPrice - currentPrice) >= TrailingStart * point)
         {
            double new_sl = NormalizeDouble(currentPrice + TrailingStep * point, digits);
            double new_tp = NormalizeDouble(tp - TrailingStart * point, digits);
            if (useSL && (new_sl < sl || sl == 0.0))
               trade.PositionModify(ticket, new_sl, useTP ? new_tp : tp);
         }

         info += StringFormat("[%d] %s %.%df\nSL: %.%df | TP: %.%df\nP/L: %.2f USD\n\n",
                              (int)ticket,
                              (type == POSITION_TYPE_BUY ? "BUY " : "SELL"),
                              digits, openPrice,
                              digits, sl,
                              digits, tp,
                              profit);
      }
   }

   // === Averaging
   if (posisi > 0 && posisi < MaxTrades && lastType != -1)
   {
      lot = GetMartingaleLot(posisi);
      if (lastType == POSITION_TYPE_BUY && bid <= (lastOpenPrice - repeatDistance) && IsBuySignal())
      {
         double sl = useSL ? NormalizeDouble(ask - slDistance, digits) : 0.0;
         double tp = useTP ? NormalizeDouble(ask + tpDistance, digits) : 0.0;
         trade.Buy(lot, _Symbol, ask, sl, tp, "Averaging Buy");
      }
      else if (lastType == POSITION_TYPE_SELL && ask >= (lastOpenPrice + repeatDistance) && IsSellSignal())
      {
         double sl = useSL ? NormalizeDouble(bid + slDistance, digits) : 0.0;
         double tp = useTP ? NormalizeDouble(bid - tpDistance, digits) : 0.0;
         trade.Sell(lot, _Symbol, bid, sl, tp, "Averaging Sell");
      }
   }

   Comment((info == "") ? "📊 Tidak ada posisi aktif" : info);
}
