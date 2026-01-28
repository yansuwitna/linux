//+------------------------------------------------------------------+
//| MA Crossover with RSI Filter, Trailing Stop, and Account Info    |
//+------------------------------------------------------------------+
#property strict

#include <Trade\Trade.mqh>
CTrade trade;

input int FastMAPeriod = 10;
input int SlowMAPeriod = 50;
input int RSIPeriod = 14;
input double LotSize = 0.01;
input double TakeProfit = 50;
input double StopLoss = 30;
input int TrailingStop = 20;  // Trailing Stop dalam pip
input ENUM_TIMEFRAMES TimeFrame = PERIOD_M1;

int fastMAHandle, slowMAHandle, rsiHandle;

//+------------------------------------------------------------------+
int OnInit()
{
   fastMAHandle = iMA(_Symbol, TimeFrame, FastMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   slowMAHandle = iMA(_Symbol, TimeFrame, SlowMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   rsiHandle    = iRSI(_Symbol, TimeFrame, RSIPeriod, PRICE_CLOSE);
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
void OnTick()
{
   double fastMA[2], slowMA[2], rsi[1];

   if (CopyBuffer(fastMAHandle, 0, 0, 2, fastMA) < 0) return;
   if (CopyBuffer(slowMAHandle, 0, 0, 2, slowMA) < 0) return;
   if (CopyBuffer(rsiHandle, 0, 0, 1, rsi) < 0) return;

   // Mengambil informasi akun
   double accountEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   double accountMargin = AccountInfoDouble(ACCOUNT_MARGIN);
   double accountFreeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);

   // Mengambil harga Ask dan Bid
   double askPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bidPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   // Menampilkan nilai MA, RSI, dan informasi akun di chart
   string info = "Fast MA: " + DoubleToString(fastMA[0], 4) + "\n" +
                 "Slow MA: " + DoubleToString(slowMA[0], 4) + "\n" +
                 "RSI: " + DoubleToString(rsi[0], 2) + "\n\n" +
                 "Equity: " + DoubleToString(accountEquity, 2) + "\n" +
                 "Balance: " + DoubleToString(accountBalance, 2) + "\n" +
                 "Margin: " + DoubleToString(accountMargin, 2) + "\n" +
                 "Free Margin: " + DoubleToString(accountFreeMargin, 2);

   // Menampilkan informasi di chart
   Comment(info);

   // Pastikan tidak ada posisi terbuka
   if (PositionsTotal() == 0)
   {
      // BUY SIGNAL
      if (fastMA[1] < slowMA[1] && fastMA[0] > slowMA[0] && rsi[0] < 70)
      {
         trade.Buy(LotSize, _Symbol, askPrice, StopLoss * _Point, TakeProfit * _Point);
      }
      // SELL SIGNAL
      else if (fastMA[1] > slowMA[1] && fastMA[0] < slowMA[0] && rsi[0] > 30)
      {
         trade.Sell(LotSize, _Symbol, bidPrice, StopLoss * _Point, TakeProfit * _Point);
      }
   }
   
   // Cek posisi yang sudah ada dan terapkan Trailing Stop jika harga bergerak sesuai posisi
   if (PositionsTotal() > 0)
   {
      // Pilih posisi pertama yang terbuka
      if (PositionSelect(_Symbol)) // Pilih posisi berdasarkan simbol
      {
         ulong ticket = PositionGetTicket(0); // Mendapatkan ticket posisi pertama
         double positionOpenPrice = PositionGetDouble(POSITION_PRICE_OPEN); // Harga pembukaan posisi
         double trailingStopLevel;

         // Mendapatkan profit dari posisi
         double positionProfit = PositionGetDouble(POSITION_PROFIT);

         // Trailing Stop untuk posisi Buy
         if (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
         {
            trailingStopLevel = askPrice - TrailingStop * _Point;
            double stopLoss = PositionGetDouble(POSITION_SL); // Menggunakan POSITION_SL untuk stop loss
            if (trailingStopLevel > stopLoss)
            {
               // Gunakan PositionModify untuk mengubah stop loss
               if (!trade.PositionModify(ticket, stopLoss, trailingStopLevel))
               {
                  Print("Error modifying position stop loss: ", GetLastError());
               }
            }
         }
         // Trailing Stop untuk posisi Sell
         else if (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
         {
            trailingStopLevel = bidPrice + TrailingStop * _Point;
            double stopLoss = PositionGetDouble(POSITION_SL); // Menggunakan POSITION_SL untuk stop loss
            if (trailingStopLevel < stopLoss)
            {
               // Gunakan PositionModify untuk mengubah stop loss
               if (!trade.PositionModify(ticket, stopLoss, trailingStopLevel))
               {
                  Print("Error modifying position stop loss: ", GetLastError());
               }
            }
         }

         // Menampilkan nilai Trailing Stop dan Profit di chart
         string trailingInfo = "\nTrailing Stop Level: " + DoubleToString(trailingStopLevel, 4) + 
                               "\nProfit: " + DoubleToString(positionProfit, 2);
         Comment(info + trailingInfo);
      }
   }
}
