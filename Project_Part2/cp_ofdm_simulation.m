% Matlab file for simulating a cyclic-prefix (CP) orthogonal-frequency-
% division-multiplexing (OFDM) system with binary phase-shift keying (BPSK) 
% modulation on each subcarrier. CP-OFDM system includes a repetition code
% and interleaving across subcarriers as well as a Rayleigh-fading channel 
% model with exponentially decaying power profile.
%
% janm Oct. 10, 2008
% ******************************************************************************

close all 
clear all

% Simulation parameters
% ---------------------

% Signal-to-noise ratios (SNRs) to be simulated
snr_dB = [0:2:20];                  % SNR in dB
snr_lin = 10.^(snr_dB/10);          % SNR linear
sigma2_n = 1./snr_lin;              % Variance of additive white Gaussian 
                                    % noise (AWGN) at receiver

% Channel model parameters
Nch = 10;           % Number of taps within the channel impulse response
c_att = 2;          % Factor for exponentially decaying power profile: 
                    %   E{h_l}/E{h_0} = exp(-l/c_att) (l=0,..,Nch-1)
Nreal = 10000;      % Number of channel realizations to be simulated

% OFDM parameters
Nc = 128;           % Number of carriers/ FFT-size 
                    % (should be 2^n)
R = 1/4;            % Code rate of employed repetition code 
                    % (must be 1 or 1/2^n, n=1,2,3,...)
intlv = 0;          % Interleaving: 0 --&gt; switched off; 1 --&gt; switched on
                    % (only useful in the case of repetition code)

% ------------------------------------------------------------------------------

% ---------------------------------
% Calculations performed in advance
% ---------------------------------

% Generate index vector for interleaving with maximum distance pattern
if ( intlv )&amp;( R &lt; 1 )
    index_matrix = [];
    for kk=1:1/R
        index_matrix = [index_matrix [(kk-1)*Nc*R+1:kk*Nc*R]' ];
    end
    index = reshape(index_matrix',1,Nc);
elseif ( ~intlv )&amp;( R &lt; 1 )
    index_matrix = reshape([1:Nc],1/R,Nc*R)';
end

% Calculate variances of channel taps according to exponetial decaying power profile
var_ch = exp(-[0:Nch-1]/c_att);  
var_ch = var_ch/sum(var_ch);        % Normalize overall average channel power to one

% --------------------
% Main simulation loop
% --------------------

% Counter for bit errors 
err_count = zeros(1,length(snr_dB));

for ii = 1:length(snr_dB)
    ii
    for jj = 1:Nreal
 
        % ----------------
        % Transmitter part
        % ----------------

        % Generate random data vector of length Nc*R with elements {-1,+1}
        U = 2*round(rand(1,R*Nc))-1;
         
        % Perform repetition encoding [+1 -1 ...] --&gt; [+1 +1 -1 -1 ...]
        if R &lt; 1
            X = kron(U,ones(1,1/R));
        else
            X = U;
        end
 
        % Perform interleaving   
        if ( intlv )&amp;( R &lt; 1 )
            X(index) = X;
        end             

       % IFFT of current OFDM symbol X including normalization factor (--&gt; unitary IFFT)  
        x = ifft(X)*sqrt(Nc);

        % Add cyclic prefix of length Nch-1 --&gt; Transmitted sequence
        x = [ x(end-Nch+2:end) x ];

        % ------------
        % Channel part
        % ------------

        % Generate random channel coefficients (Rayleigh fading)
        h = sqrt(0.5)*( randn(1,Nch) + j*randn(1,Nch) ) .* sqrt(var_ch); 

        % Calculate corresponding frequency response (needed for receiver part)
        h_zp = [h zeros(1,Nc-Nch)];                  % Zero-padded channel impulse response (length Nc)
        H = fft(h_zp);                               % Corresponding FFT 

        % Received sequence --&gt; Convolution with channel impulse response
        y = conv(x,h);

        % Add AWGN 
        n = sqrt(0.5*sigma2_n(ii)) * ( randn(1,length(y)) + j*randn(1,length(y)) );
        y = y + n;

        % Discard last Nch-1 received values resulting from convolution
        y(end-Nch+2:end) = [];   

        % -------------
        % Receiver part
        % -------------

        % Remove cyclic prefix
        y(1:Nch-1) = [];   
 
        % FFT of received vector including normalization factor (--&gt; unitary FFT)
        Y = fft(y)/sqrt(Nc);

        % Perform deinterleaving and repetition decoding (--&gt; maximum ratio combining)
        Z = conj(H) .* Y;                   % Derotation and weighting
        if R == 1
            Uhat = sign(real(Z));
        else
            matrix_help = Z(index_matrix);  % Perform deinterleaving
            Z_mrc = sum(matrix_help,2);     % Maximum ratio combining
            Uhat = sign(real(Z_mrc))';      % Hard decision on information symbols
        end 

        % Bit error count
        err_count(ii) =  err_count(ii) + sum(abs(Uhat-U))/2;

    end % loop over all channel realizations
end % loop over all SNR values 

% Calculate final bit error rate (BER)
ber = err_count/(R*Nc*Nreal);


% ----------------------
% Analytical BER results
% ----------------------

% Analytical bit error probability for Rayleigh fading (diversity order 1, 2, 4) 
ber_ray_L1 = proakis_equalSNRs(snr_dB,1);
ber_ray_L2 = proakis_equalSNRs(snr_dB,2);
ber_ray_L4 = proakis_equalSNRs(snr_dB,4);


% -------
% Figures
% -------

% Plot one random realization of channel frequency response (last one simulated)
figure
set(gca,'FontSize',12);
h=plot(abs(H),'b-');
set(h,'LineWidth',1);
hold on
if R &lt; 1
    for ii=1:1/R
        if intlv
           h=stem(index(ii),abs(H(index(ii))),'r');
           set(h,'MarkerSize',7,'LineWidth',1);
        else
           h=stem(ii,abs(H(ii)),'r');
           set(h,'MarkerSize',7,'LineWidth',1);
        end
    end
end
xlabel('Carrier No.')
ylabel('Channel Frequency Response (Magnitude)')
axis([1 Nc 0 1.1*max(abs(H))])
grid on

% BER plot
figure
set(gca,'FontSize',12);
h=semilogy(snr_dB,ber,'ko--');
set(h,'MarkerSize',7,'LineWidth',1);
hold on
h=semilogy(snr_dB,ber_ray_L1,'rx-');
set(h,'MarkerSize',7,'LineWidth',1);
h=semilogy(snr_dB,ber_ray_L2,'m+-');
set(h,'MarkerSize',7,'LineWidth',1);
h=semilogy(snr_dB,ber_ray_L4,'b*-');
set(h,'MarkerSize',7,'LineWidth',1);
legend('Simulation','Rayleigh fading (L=1, theory)','Rayleigh fading (L=2, theory)','Rayleigh fading (L=4, theory)')
xlabel('1/\sigma_n^2 in dB')
ylabel('BER')
axis([snr_dB(1) snr_dB(end) 0.0001 1])
grid on

 </pre></body></html>Ztext/plainUUTF-8    ( ? N ` v ? ? ???             
              ?