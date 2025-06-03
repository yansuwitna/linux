
//Menggunakan BB, RSI dan MA
//Mengikuti Waktu 
//Berisi Trailing Stop 

#property strict

#include <Trade\Trade.mqh>
CTrade trade;

// === INPUT ===
input double LotSize        = 0.01;
input int    SLPoints       = 50;
input int    TPPoints       = 70;
input int    BBPeriod       = 20;
input double BBDeviation    = 2.0;
input int    RSIPeriod      = 14;
input double RSI_Buy_Max    = 50.0;
input double RSI_Sell_Min   = 50.0;
input int    TradingStartHour = 1;
input int    TradingEndHour   = 17;
input int    TrailingStart    = 50;
input int    TrailingStep     = 20;

// === HANDLES & BUFFERS ===
int bb_handle, rsi_handle;
double upper[], lower[], rsiBuffer[], middle[];

#property indicator_chart_window
#property indicator_buffers 2
#property indicator_plots   2

#property indicator_type1   DRAW_ARROW
#property indicator_color1  clrLime
#property indicator_width1  1
#property indicator_label1  "Bullish Engulfing"

#property indicator_type2   DRAW_ARROW
#property indicator_color2  clrRed
#property indicator_width2  1
#property indicator_label2  "Bearish Engulfing"

double BullBuffer[];
double BearBuffer[];

//+------------------------------------------------------------------+
//| Fungsi bantu: TimeHour                                           |
//+------------------------------------------------------------------+
int TimeHour(datetime t) {
   MqlDateTime tm;
   TimeToStruct(t, tm);
   return tm.hour;
}

//+------------------------------------------------------------------+
int OnInit()
{
    bb_handle = iBands(_Symbol, _Period, BBPeriod, 0, BBDeviation, PRICE_CLOSE);
    rsi_handle = iRSI(_Symbol, _Period, RSIPeriod, PRICE_CLOSE);

    if (bb_handle == INVALID_HANDLE || rsi_handle == INVALID_HANDLE)
    {
        Comment("❌ Gagal inisialisasi indikator.");
        return INIT_FAILED;
    }
    
    SetIndexBuffer(0, BullBuffer);
   PlotIndexSetInteger(0, PLOT_ARROW, 233); // panah ke atas
   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);

   SetIndexBuffer(1, BearBuffer);
   PlotIndexSetInteger(1, PLOT_ARROW, 234); // panah ke bawah
   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, EMPTY_VALUE);
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
void OnTick()
{
    int hourNow = TimeHour(TimeCurrent());
    if (hourNow < TradingStartHour || hourNow > TradingEndHour)
    {
        Comment("⏰ Di luar jam trading: ", hourNow, ":00");
        return;
    }

    if (CopyBuffer(bb_handle, 0, 0, 1, upper) <= 0 ||
         CopyBuffer(bb_handle, 1, 0, 1, middle) <= 0 ||
        CopyBuffer(bb_handle, 2, 0, 1, lower) <= 0 ||
        CopyBuffer(rsi_handle, 0, 0, 1, rsiBuffer) <= 0)
    {
        Comment("❌ Gagal membaca data indikator.");
        return;
    }

    double close   = iClose(_Symbol, _Period, 0);
    double upperBB = upper[0];
    double lowerBB = lower[0];
    double middleBB = middle[0];
    double rsi     = rsiBuffer[0];
    //double ma200   = iMA(_Symbol, _Period, 200, 0, MODE_SMA, PRICE_CLOSE);
    double ma200   = middleBB;

    string info =
        "🔰 EA BB-RSI Advanced \n\n" +
        "Balance     : $" + DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE), 2) + "\n" +
        "Equity      : $" + DoubleToString(AccountInfoDouble(ACCOUNT_EQUITY), 2) + "\n" +
        "Margin      : $" + DoubleToString(AccountInfoDouble(ACCOUNT_MARGIN), 2) + "\n" +
        "Free Margin : $" + DoubleToString(AccountInfoDouble(ACCOUNT_FREEMARGIN), 2) + "\n" +
        "Profit      : $" + DoubleToString(AccountInfoDouble(ACCOUNT_PROFIT), 2) + "\n" +
        "RSI         : " + DoubleToString(rsi, 5) + "\n" +
        "Upper BB    : " + DoubleToString(upperBB, 5) + "\n" +
        "Lower BB    : " + DoubleToString(lowerBB, 5) + "\n" +
        "MA200       : " + DoubleToString(ma200, 5) + "\n" +
        "Price       : " + DoubleToString(close, 5) + "\n" + 
        "WAKTU       : " + EnumToString(_Period) + "\n";
        
        
        
        info += "\n================ Logika BUY ================\n\n";
     info += "Close <= LowerBB : ";
     info += DoubleToString(close,5) + " <= " + DoubleToString(lowerBB, 5) + " : " + (close <= lowerBB?"Benar":"Salah")  + "\n";
     info += "RSI < RSI_Buy_Max : ";
     info += DoubleToString(rsi,0) + " < " + RSI_Buy_Max + " : " + (rsi < RSI_Buy_Max?"Benar":"Salah")  + "\n";
     info += "Close > MA : ";
     info += DoubleToString(close,5) + " > " + DoubleToString(ma200,5) + " : " + (close > ma200?"Benar":"Salah")  + "\n";
     
     info += "Kesimpulan : ";
     info += ((close <= lowerBB && rsi < RSI_Buy_Max && close > ma200)?"Benar":"Salah")  + "\n";
    
     info += "\n================ Logika SELL ================\n\n";
     info += "Close >= upperBB : ";
     info += DoubleToString(close,5) + " >= " + DoubleToString(upperBB, 5) + " : " + (close >= upperBB?"Benar":"Salah")  + "\n";
     info += "RSI > RSI_Sell_Min : ";
     info += DoubleToString(rsi,0) + " > " + RSI_Sell_Min + " : " + (rsi > RSI_Sell_Min?"Benar":"Salah")  + "\n";
     info += "Close < MA : ";
     info += DoubleToString(close,5) + " < " + DoubleToString(ma200,5) + " : " + (close < ma200?"Benar":"Salah")  + "\n";
     
     info += "Kesimpulan : ";
     info += ((close >= upperBB && rsi > RSI_Sell_Min && close < ma200)?"Benar":"Salah")  + "\n\n\n";
    


    if (PositionsTotal() > 0)
    {
        TrailPositions();
        Comment(info + "⏳ Menunggu posisi selesai...");
        return;
    }

    double sl, tp;
    
     
    if (close <= lowerBB && rsi < RSI_Buy_Max && close > ma200)
    {
        sl = close - SLPoints * _Point;
        tp = close + TPPoints * _Point;
        if (trade.Buy(LotSize, _Symbol, close, sl, tp, "BUY BB-RSI"))
            info += "✅ BUY dibuka @ " + DoubleToString(close, 2);
        else
            info += "❌ Gagal membuka BUY";
    }
    else if (close >= upperBB && rsi > RSI_Sell_Min && close < ma200)
    {
        sl = close + SLPoints * _Point;
        tp = close - TPPoints * _Point;
        if (trade.Sell(LotSize, _Symbol, close, sl, tp, "SELL BB-RSI"))
            info += "✅ SELL dibuka @ " + DoubleToString(close, 2);
        else
            info += "❌ Gagal membuka SELL";
    }
    else
    {
        info += "🔍 Tidak ada sinyal valid.";
    }

    Comment(info);
}

//+------------------------------------------------------------------+
void TrailPositions()
{
    for (int i = 0; i < PositionsTotal(); i++)
    {
        if (!PositionGetTicket(i)) continue;
        if (PositionGetString(POSITION_SYMBOL) != _Symbol) continue;

        ulong ticket     = PositionGetInteger(POSITION_TICKET);
        double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
        double sl        = PositionGetDouble(POSITION_SL);
        double tp        = PositionGetDouble(POSITION_TP);
        int type         = (int)PositionGetInteger(POSITION_TYPE);

        double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
        double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

        if (type == POSITION_TYPE_BUY)
        {
            double profitPoints = (bid - openPrice) / _Point;
            if (profitPoints > TrailingStart)
            {
                double newSL = bid - TrailingStep * _Point;
                if (newSL > sl)
                    trade.PositionModify(ticket, newSL, tp);
            }
        }
        else if (type == POSITION_TYPE_SELL)
        {
            double profitPoints = (openPrice - ask) / _Point;
            if (profitPoints > TrailingStart)
            {
                double newSL = ask + TrailingStep * _Point;
                if (newSL < sl)
                    trade.PositionModify(ticket, newSL, tp);
            }
        }
    }
}

int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
   for (int i = 1; i < rates_total; i++)
   {
      BullBuffer[i] = EMPTY_VALUE;
      BearBuffer[i] = EMPTY_VALUE;

      // Bullish Engulfing
      if (close[i] > open[i] && close[i - 1] < open[i - 1] &&
          open[i] < close[i - 1] && close[i] > open[i - 1])
      {
         BullBuffer[i] = low[i] - (10 * _Point);
      }

      // Bearish Engulfing
      if (close[i] < open[i] && close[i - 1] > open[i - 1] &&
          open[i] > close[i - 1] && close[i] < open[i - 1])
      {
         BearBuffer[i] = high[i] + (10 * _Point);
      }
   }

   return rates_total;
}
