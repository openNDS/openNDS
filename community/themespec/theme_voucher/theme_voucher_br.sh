#!/bin/sh
#Copyright (C) The openNDS Contributors 2004-2021
#Copyright (C) BlueWave Projects and Services 2015-2021
#Copyright (C) Francesco Servida 2022
#This software is released under the GNU GPL license.
#
# Warning - shebang sh is for compatibliity with busybox ash (eg on OpenWrt)
# This must be changed to bash for use on generic Linux
#

vform='
	<med-blue>
		Bem Vindo!
	</med-blue><br>
	<hr>
	Seu IP: %s <br>
	Seu MAC: %s <br>
	<hr>
	<form action="/opennds_preauth/" method="get">
		<input type="hidden" name="fas" value="%s"> 
		<input type="checkbox" name="tos" value="accepted" required> Eu aceito os termos de uso. <br>
		C&oacute;digo de acesso #: <input type="text" name="voucher" value="" required><br>
		<input type="submit" value="Connect">
	</form>
	<br>
'
#	Your IP: $clientip <br>
#	Your MAC: $clientmac <br>

invalid_voucher='
	<big-red>O &quot;c&oacute;digo de acesso&quot; n&atilde;o &eacute; v&aacute;lido, clique em Continuar para reiniciar o login <br></big-red>
	<form>
		<input type="button" VALUE="Continue" onClick="history.go(-1);return true;">
	</form>
'

auth_success='
	<p>
		<big-red>
			Agora voc&ecirc; est&aacute; logado e tem acesso &agrave; Internet.
		</big-red>
		<hr>
	</p>
	Este &quot;c&oacute;digo de acesso&quot; &eacute; v&aacute;lido para $session_length minutos.
	<hr>
	<p>
		<italic-black>
			Voc&ecirc; pode usar seu navegador, e-mail e outros aplicativos de rede como faria normalmente.
		</italic-black>
	</p>
	<p>
		Seu dispositivo solicitou originalmente <b>$originurl</b>
		<br>
		Clique ou toque em Continuar para ir para l&aacute;.
	</p>
	<form>
		<input type="button" VALUE="Continue" onClick="history.go(-1);return true;">
	</form>
	<hr>
'

#		<input type="button" VALUE="Continue" onClick="location.href='"'"'$originurl'"'"'" >

auth_fail='
	<p>
		<big-red>
			Algo deu errado e voc&ecirc; n&atilde;o conseguiu fazer login.
		</big-red>
		<hr>
	</p>
	<hr>
	<p>
		<italic-black>
			Sua tentativa de login provavelmente expirou.
		</italic-black>
	</p>
	<p>
		<br>
		Clique ou toque em Continuar para tentar novamente.
	</p>
	<form>
		<input type="button" VALUE="Continue" onClick="history.go(-1);return true;">
	</form>
	<hr>
'

terms_button='
	<form action="/opennds_preauth/" method="get">
		<input type="hidden" name="fas" value="$fas">
		<input type="hidden" name="terms" value="yes">
		<input type="submit" value="Read Terms of Service   " >
	</form>
'


# WARNING #
# This is the all important "Terms of service"
# Edit this long winded generic version to suit your requirements.
# It is your responsibility to ensure these "Terms of Service" are compliant with the REGULATIONS and LAWS of your Country or State.
# In most locations, a Privacy Statement is an essential part of the Terms of Service.
	
terms_privacy='
	<b style="color:red;">Privacidade</b><br>
	<b>
		Ao fazer login no sistema, voc&ecirc; concede sua permiss&atilde;o para que este sistema armazene quaisquer dados que voc&ecirc; fornecer
        as finalidades de login, juntamente com os par&acirc;metros de rede do seu dispositivo que o sistema requer para funcionar. <br>
		Todas as informa&ccedil;&otilde;es s&atilde;o armazenadas para sua conveni&ecirc;ncia e para a sua prote&ccedil;&atilde;o e a nossa. <br>
		Todas as informa&ccedil;&otilde;es coletadas por este sistema s&atilde;o armazenadas de forma segura e n&atilde;o s&atilde;o acess&iacute;veis a terceiros. <br>
	</b><hr>
'

terms_service='
	<b style="color:red;">Termos de Servi&ccedil;o para este Hotspot.</b> <br>
	<b>O acesso &eacute; concedido com base na confian&ccedil;a de que voc&ecirc; N&Atilde;O usar&aacute; ou abusar&aacute; desse acesso de forma alguma.</b><hr>
	<b>Role para baixo para ler os Termos de Servi&ccedil;o na &iacute;ntegra ou clique no bot&atilde;o Continuar para retornar &agrave; P&aacute;gina de Aceita&ccedil;&atilde;o </b>
	<form>
		<input type="button" VALUE="Continue" onClick="history.go(-1);return true;">
	</form>
'

terms_use='
	<hr>
	<b>Uso adequado</b>
	<p>
		Este Hotspot fornece uma rede sem fio que permite conectar-se &agrave; Internet. <br>
		<b>O uso desta conex&atilde;o com a Internet &eacute; fornecido em troca de sua aceita&ccedil;&atilde;o TOTAL destes Termos de Servi&ccedil;o.</b>
	</p>
	<p>
		<b>Voc&ecirc; concorda </b> que &eacute; respons&aacute;vel por fornecer medidas de seguran&ccedil;a adequadas para o uso pretendido do Servi&ccedil;o.
		Por exemplo, voc&ecirc; deve assumir total responsabilidade por tomar as medidas adequadas para proteger seus dados contra perda.
	</p>
	<p>
		Embora o Hotspot use esfor&ccedil;os comercialmente razo&aacute;veis ​​para fornecer um servi&ccedil;o seguro,
        a efic&aacute;cia desses esfor&ccedil;os n&atilde;o pode ser garantida.
	</p>
	<p>
		<b>Voc&ecirc; deve</b> usar a tecnologia fornecida a voc&ecirc; por este Hotspot para o &uacute;nico prop&oacute;sito
		de usar o Servi&ccedil;o conforme descrito aqui.
		Voc&ecirc; deve notificar imediatamente o Propriet&aacute;rio sobre qualquer uso n&atilde;o autorizado do Servi&ccedil;o ou qualquer outra viola&ccedil;&atilde;o de seguran&ccedil;a.<br><br>
		Daremos a voc&ecirc; um endere&ccedil;o IP cada vez que voc&ecirc; acessar o Hotspot, e ele pode mudar.
		<br>
		<b>Voc&ecirc; n&atilde;o deve </b> programar nenhum outro endere&ccedil;o IP ou MAC em seu dispositivo que acesse o Hotspot.
		Voc&ecirc; n&atilde;o pode usar o Servi&ccedil;o por qualquer outro motivo, incluindo revender qualquer aspecto do Servi&ccedil;o.
		Outros exemplos de atividades impr&oacute;prias incluem, sem limita&ccedil;&atilde;o:
	</p>
		<ol>
			<li>
				download ou upload de grandes volumes de dados que o desempenho do Servi&ccedil;o torna-se
				visivelmente degradado para outros usu&aacute;rios por um per&iacute;odo significativo;
			</li>
			<li>
				tentar quebrar a seguran&ccedil;a, acessar, adulterar ou usar qualquer &aacute;rea n&atilde;o autorizada do Servi&ccedil;o;
			</li>
			<li>
				remover qualquer direito autoral, marca registrada ou outros avisos de direitos de propriedade contidos no ou no Servi&ccedil;o;
			</li>
			<li>
				tentando coletar ou manter qualquer informa&ccedil;&atilde;o sobre outros usu&aacute;rios do Servi&ccedil;o
				(incluindo nomes de usu&aacute;rios e/ou endere&ccedil;os de e-mail) ou outros terceiros para fins n&atilde;o autorizados;
			</li>
			<li>
				fazer login no Servi&ccedil;o sob pretextos falsos ou fraudulentos;
			</li>
			<li>
				criar ou transmitir comunica&ccedil;&otilde;es eletr&ocirc;nicas indesejadas, como SPAM ou correntes para outros usu&aacute;rios
				ou de outra forma interferir no aproveitamento do servi&ccedil;o por outro usu&aacute;rio;
			</li>
			<li>
				transmitir quaisquer v&iacute;rus, worms, defeitos, Cavalos de Tr&oacute;ia ou outros itens de natureza destrutiva; ou
			</li>
			<li>
				usar o Servi&ccedil;o para qualquer finalidade ilegal, assediante, abusiva, criminosa ou fraudulenta.
			</li>
		</ol>
'

terms_content='
	<hr>
	<b>Isen&ccedil;&atilde;o de responsabilidade de conte&uacute;do</b>
	<p>
		Os Propriet&aacute;rios do Hotspot n&atilde;o controlam e n&atilde;o s&atilde;o respons&aacute;veis ​​por dados, conte&uacute;do, servi&ccedil;os ou produtos
		que s&atilde;o acessados ​​ou baixados por meio do Servi&ccedil;o.
		Os Propriet&aacute;rios podem, mas n&atilde;o s&atilde;o obrigados a, bloquear as transmiss&otilde;es de dados para proteger o Propriet&aacute;rio e o P&uacute;blico.
	</p>
	Os Propriet&aacute;rios, seus fornecedores e seus licenciadores expressamente se isentam em toda a extens&atilde;o permitida por lei,
	todas as garantias expressas, impl&iacute;citas e estatut&aacute;rias, incluindo, sem limita&ccedil;&atilde;o, as garantias de comercializa&ccedil;&atilde;o
	ou adequa&ccedil;&atilde;o a um prop&oacute;sito espec&iacute;fico.
	<br><br>
	Os Propriet&aacute;rios, seus fornecedores e seus licenciadores expressamente se isentam em toda a extens&atilde;o permitida por lei
	qualquer responsabilidade por viola&ccedil;&atilde;o de direitos de propriedade e/ou viola&ccedil;&atilde;o de direitos autorais por qualquer usu&aacute;rio do sistema.
	Detalhes de login e identidades de dispositivos podem ser armazenados e usados ​​como prova em um Tribunal de Justi&ccedil;a contra esses usu&aacute;rios.
	<br>
'

terms_liability='
	<hr><b>Limita&ccedil;&atilde;o de responsabilidade</b>
	<p>
		Sob nenhuma circunst&acirc;ncia os Propriet&aacute;rios, seus fornecedores ou seus licenciadores ser&atilde;o respons&aacute;veis ​​por qualquer usu&aacute;rio ou
		qualquer terceiro por conta do uso ou uso indevido dessa parte ou confian&ccedil;a no Servi&ccedil;o.
	</p>
	<hr><b>Altera&ccedil;&otilde;es nos Termos de Servi&ccedil;o e Rescis&atilde;o</b>
	<p>
		Podemos modificar ou rescindir o Servi&ccedil;o e estes Termos de Servi&ccedil;o e quaisquer pol&iacute;ticas associadas,
		por qualquer motivo e sem aviso pr&eacute;vio, incluindo o direito de rescindir com ou sem aviso pr&eacute;vio,
		sem responsabilidade perante voc&ecirc;, qualquer usu&aacute;rio ou terceiros. Revise estes Termos de Servi&ccedil;o
		de tempos em tempos, para que voc&ecirc; seja informado sobre quaisquer altera&ccedil;&otilde;es.
	</p>
	<p>
		Reservamo-nos o direito de encerrar seu uso do Servi&ccedil;o, por qualquer motivo e sem aviso pr&eacute;vio.
		Ap&oacute;s tal rescis&atilde;o, todos e quaisquer direitos concedidos a voc&ecirc; por este Propriet&aacute;rio do Hotspot ser&atilde;o rescindidos.
	</p>
'

terms_indemnity='
	<hr><b>Indeniza&ccedil;&atilde;o</b>
	<p>
		<b>Voc&ecirc; concorda</b> isentar e indenizar os Propriet&aacute;rios deste Hotspot,
		seus fornecedores e licenciantes de e contra qualquer reclama&ccedil;&atilde;o de terceiros decorrente de
		ou de qualquer forma relacionado ao seu uso do Servi&ccedil;o, incluindo qualquer responsabilidade ou despesa decorrente de todas as reclama&ccedil;&otilde;es,
		perdas, danos (reais e consequentes), processos, senten&ccedil;as, custas judiciais e honor&aacute;rios advocat&iacute;cios, de toda esp&eacute;cie e natureza.
	</p>
	<hr>
	<form>
		<input type="button" VALUE="Continue" onClick="history.go(-1);return true;">
	</form>
'
