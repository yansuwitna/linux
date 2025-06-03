#property strict
#include <Trade\Trade.mqh>
CTrade trade;

// ===== INPUT =====
input int MaxCandles         = 10;
input double LotSize         = 0.1;
input int TrailingStart      = 5;
input int TrailingStep       = 5;
input double SL_Multiplier   = 10;
input double TP_Multiplier   = 20;
input bool useSL             = true;
input bool useTP             = true;
input double RepeatMultiplier = 5;
input int MaxTrades           = 10; // Maksimal posisi per simbol

//+------------------------------------------------------------------+
// Hitung jumlah posisi aktif untuk simbol ini
int CountPositions(string symbol)
{
   int total = 0;
   for (int i = 0; i < PositionsTotal(); i++)
   {
      if (PositionGetTicket(i) > 0 && PositionGetString(POSITION_SYMBOL) == symbol)
         total++;
   }
   return total;
}

//+------------------------------------------------------------------+
int OnInit()
{
   Comment("");
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
void OnTick()
{
   double point      = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   int digits        = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   double spread     = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) * point;

   double slDistance = spread * SL_Multiplier;
   double tpDistance = spread * TP_Multiplier;
   double repeatDistance = spread * RepeatMultiplier;

   double volumeStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double lotMin     = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double lotMax     = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);

   double lot = MathFloor(LotSize / volumeStep) * volumeStep;
   lot = MathMax(lotMin, MathMin(lot, lotMax));
   lot = NormalizeDouble(lot, 2);

   // Panah candle
   for (int i = 0; i < MaxCandles && i < Bars(_Symbol, _Period); i++)
   {
      double open  = iOpen(_Symbol, _Period, i);
      double close = iClose(_Symbol, _Period, i);
      double high  = iHigh(_Symbol, _Period, i);
      double low   = iLow(_Symbol, _Period, i);
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

   // === ENTRY POSISI UTAMA ===
   if (CountPositions(_Symbol) == 0)
   {
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double open = iOpen(_Symbol, _Period, 0);
      double close = iClose(_Symbol, _Period, 0);

      trade.SetDeviationInPoints(20);
      trade.SetTypeFilling(ORDER_FILLING_IOC);

      double sl, tp;

      if (close > open) // BUY
      {
         sl = useSL ? NormalizeDouble(ask - slDistance, digits) : 0.0;
         tp = useTP ? NormalizeDouble(ask + tpDistance, digits) : 0.0;
         trade.Buy(lot, _Symbol, ask, sl, tp, "Buy Bullish");
      }
      else if (close < open) // SELL
      {
         sl = useSL ? NormalizeDouble(bid + slDistance, digits) : 0.0;
         tp = useTP ? NormalizeDouble(bid - tpDistance, digits) : 0.0;
         trade.Sell(lot, _Symbol, bid, sl, tp, "Sell Bearish");
      }
   }

   // === TRAILING STOP + TP DINAMIS + AVERAGING ===
   string info = "";
   if (PositionSelect(_Symbol))
   {
      long type        = PositionGetInteger(POSITION_TYPE);
      double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      double sl        = PositionGetDouble(POSITION_SL);
      double tp        = PositionGetDouble(POSITION_TP);
      double profit    = PositionGetDouble(POSITION_PROFIT);

      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double currentPrice = (type == POSITION_TYPE_BUY) ? bid : ask;

      // === Trailing Stop + Geser TP
      if (type == POSITION_TYPE_BUY && (currentPrice - openPrice) >= TrailingStart * point)
      {
         double new_sl = NormalizeDouble(currentPrice - TrailingStep * point, digits);
         double new_tp = NormalizeDouble(tp + TrailingStart * point, digits);
         if (useSL && new_sl > sl)
            trade.PositionModify(_Symbol, new_sl, useTP ? new_tp : tp);
         info = "🟢 BUY\n";
      }

      if (type == POSITION_TYPE_SELL && (openPrice - currentPrice) >= TrailingStart * point)
      {
         double new_sl = NormalizeDouble(currentPrice + TrailingStep * point, digits);
         double new_tp = NormalizeDouble(tp - TrailingStart * point, digits);
         if (useSL && (new_sl < sl || sl == 0.0))
            trade.PositionModify(_Symbol, new_sl, useTP ? new_tp : tp);
         info = "🔴 SELL\n";
      }

      // === AVERAGING jika jumlah posisi < MaxTrades
      if (CountPositions(_Symbol) < MaxTrades)
      {
         double sl_add, tp_add;

         if (type == POSITION_TYPE_BUY && bid <= (openPrice - repeatDistance))
         {
            sl_add = useSL ? NormalizeDouble(ask - slDistance, digits) : 0.0;
            tp_add = useTP ? NormalizeDouble(ask + tpDistance, digits) : 0.0;
            trade.Buy(lot, _Symbol, ask, sl_add, tp_add, "Averaging Buy");
         }

         if (type == POSITION_TYPE_SELL && ask >= (openPrice + repeatDistance))
         {
            sl_add = useSL ? NormalizeDouble(bid + slDistance, digits) : 0.0;
            tp_add = useTP ? NormalizeDouble(bid - tpDistance, digits) : 0.0;
            trade.Sell(lot, _Symbol, bid, sl_add, tp_add, "Averaging Sell");
         }
      }

      info += StringFormat("Open  : %.%df\nSL    : %.%df\nTP    : %.%df\nProfit: %.2f USD",
                           digits, openPrice, digits, sl, digits, tp, profit);
      Comment(info);
   }
   else
   {
      Comment("📊 Tidak ada posisi aktif di ", _Symbol);
   }
}


/* 
| Fitur                                              | Status |
| -------------------------------------------------- | ------ |
| Buy/Sell berdasarkan candle berjalan               | ✅      |
| SL & TP berdasarkan spread × multiplier            | ✅      |
| SL/TP bisa diaktifkan via input                    | ✅      |
| Lot manual                                         | ✅      |
| Trailing Stop aktif                                | ✅      |
| TP bergerak menjauh saat trailing aktif            | ✅      |
| Panel info posisi berjalan                         | ✅      |
| Tanda panah candle bullish/bearish                 | ✅      |
| Averaging transaksi arah sama berdasarkan X×spread | ✅      |
| 🔢 Batas maksimal jumlah transaksi/simbol          | ✅      |
| Aman untuk multi-chart, multi-symbol               | ✅      |

*/