//+------------------------------------------------------------------+
//| MA Crossover with RSI Filter, Trailing Stop, Bollinger Bands     |
//+------------------------------------------------------------------+
#property strict

#include <Trade\Trade.mqh>
CTrade trade;

input int FastMAPeriod = 10;
input int SlowMAPeriod = 50;
input int RSIPeriod = 14;
input int BollingerPeriod = 20;      // Periode Bollinger Bands
input double LotSize = 0.01;         // Lot size diubah menjadi 0.01
input double TakeProfit = 50;
input double StopLoss = 30;
input int TrailingStop = 20;         // Trailing Stop dalam pip
input ENUM_TIMEFRAMES TimeFrame = PERIOD_M1;  // Mengubah time frame menjadi M1 (1 menit)
input double BollingerDeviation = 2.0; // Deviasi standar untuk Bollinger Bands

// Input tambahan untuk batas atas dan bawah RSI
input int RSIUpperLimit = 70; // Batas atas RSI (Overbought)
input int RSILowerLimit = 30; // Batas bawah RSI (Oversold)

int fastMAHandle, slowMAHandle, rsiHandle, bollingerHandle;

//+------------------------------------------------------------------+
int OnInit()
{
   fastMAHandle = iMA(_Symbol, TimeFrame, FastMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   slowMAHandle = iMA(_Symbol, TimeFrame, SlowMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   rsiHandle    = iRSI(_Symbol, TimeFrame, RSIPeriod, PRICE_CLOSE);
   bollingerHandle = iBands(_Symbol, TimeFrame, BollingerPeriod, BollingerDeviation, 0, PRICE_CLOSE);
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
void OnTick()
{
   double fastMA[2], slowMA[2], rsi[1], upperBand[2], lowerBand[2], middleBand[2];

   if (CopyBuffer(fastMAHandle, 0, 0, 2, fastMA) < 0) return;
   if (CopyBuffer(slowMAHandle, 0, 0, 2, slowMA) < 0) return;
   if (CopyBuffer(rsiHandle, 0, 0, 1, rsi) < 0) return;
   if (CopyBuffer(bollingerHandle, 0, 0, 2, upperBand) < 0) return;
   if (CopyBuffer(bollingerHandle, 1, 0, 2, lowerBand) < 0) return;
   if (CopyBuffer(bollingerHandle, 2, 0, 2, middleBand) < 0) return;

   // Mengambil informasi akun
   double accountEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   double accountMargin = AccountInfoDouble(ACCOUNT_MARGIN);
   double accountFreeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);

   // Mengambil harga Ask dan Bid
   double askPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bidPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   // Menampilkan nilai MA, RSI, Bollinger Bands, dan informasi akun di chart
   string info = "Fast MA: " + DoubleToString(fastMA[0], 4) + "\n" +
              "Slow MA: " + DoubleToString(slowMA[0], 4) + "\n" +
              "RSI: " + DoubleToString(rsi[0], 2) + "\n" +
              "RSI Limit: " + IntegerToString(RSILowerLimit) + " - " + IntegerToString(RSIUpperLimit) + "\n\n" +
              "Upper Band: " + DoubleToString(upperBand[0], 4) + "\n" +
              "Middle Band: " + DoubleToString(middleBand[0], 4) + "\n" +
              "Lower Band: " + DoubleToString(lowerBand[0], 4) + "\n\n" +
              "Equity: " + DoubleToString(accountEquity, 2) + "\n" +
              "Balance: " + DoubleToString(accountBalance, 2) + "\n" +
              "Margin: " + DoubleToString(accountMargin, 2) + "\n" +
              "Free Margin: " + DoubleToString(accountFreeMargin, 2) + "\n\n" +
              "Lot Size: " + DoubleToString(LotSize, 2) + "\n" +
              "Take Profit: " + DoubleToString(TakeProfit, 0) + " pip\n" +
              "Stop Loss: " + DoubleToString(StopLoss, 0) + " pip\n" +
              "Trailing Stop: " + IntegerToString(TrailingStop) + " pip\n" +
              "Time Frame: " + EnumToString(TimeFrame);


   // Menampilkan informasi di chart
   Comment(info);

   // Cek apakah harga saat ini berada di atas atau di bawah Bollinger Bands
   bool priceAboveUpperBand = (askPrice > upperBand[0]);
   bool priceBelowLowerBand = (askPrice < lowerBand[0]);

   // Pastikan tidak ada posisi terbuka
   if (PositionsTotal() == 0)
   {
      // BUY SIGNAL dengan Bollinger Bands dan RSI
      if (fastMA[1] < slowMA[1] && fastMA[0] > slowMA[0] && rsi[0] < RSIUpperLimit && rsi[0] > RSILowerLimit && priceBelowLowerBand)
      {
         trade.Buy(LotSize, _Symbol, askPrice, StopLoss * _Point, TakeProfit * _Point);
      }
      // SELL SIGNAL dengan Bollinger Bands dan RSI
      else if (fastMA[1] > slowMA[1] && fastMA[0] < slowMA[0] && rsi[0] > RSILowerLimit && rsi[0] < RSIUpperLimit && priceAboveUpperBand)
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
